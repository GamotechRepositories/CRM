import mongoose from 'mongoose';
import { buildDirectParticipantKey } from './chatFields.js';

const toObjectId = (id) => {
  if (!id || !mongoose.Types.ObjectId.isValid(id)) return null;
  return new mongoose.Types.ObjectId(id);
};

const previewText = (body, max = 80) => {
  const text = String(body || '').trim();
  if (text.length <= max) return text;
  return `${text.slice(0, max)}…`;
};

const TEAM_PARTICIPANT_KEY = 'team';

const toDayKey = (date) => {
  const d = new Date(date);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

const getDayBoundaries = (dayParam = 'today') => {
  let base = new Date();
  if (dayParam !== 'today') {
    const parsed = new Date(`${dayParam}T12:00:00`);
    if (!Number.isNaN(parsed.getTime())) base = parsed;
  }
  const start = new Date(base);
  start.setHours(0, 0, 0, 0);
  const end = new Date(base);
  end.setHours(23, 59, 59, 999);
  return { start, end, dayKey: toDayKey(start) };
};

const normalizeMentions = (mentions = []) => {
  if (!Array.isArray(mentions)) return [];
  return mentions
    .filter((m) => m?.employee && mongoose.Types.ObjectId.isValid(m.employee))
    .map((m) => ({
      employee: m.employee,
      name: String(m.name || '').trim(),
    }))
    .filter((m) => m.name);
};

export const createChatHandlers = ({ Conversation, Message, Employee, tenantId, getChatIntegration }) => {
  const ensureTeamConversation = async () => {
    let conversation = await Conversation.findOne({ type: 'team', participantKey: TEAM_PARTICIPANT_KEY });
    if (!conversation) {
      conversation = await Conversation.create({
        type: 'team',
        participantKey: TEAM_PARTICIPANT_KEY,
        title: 'Team Chat',
        participants: [],
        lastMessageAt: new Date(),
      });
    }
    return conversation;
  };

  const assertCanAccess = async (conversationId, employeeId) => {
    const conv = await Conversation.findById(conversationId);
    if (!conv) return { error: { status: 404, message: 'Conversation not found' } };

    const employee = await Employee.findById(employeeId).select('_id name');
    if (!employee) return { error: { status: 403, message: 'Invalid employee' } };

    if (conv.type === 'team') {
      return { conv, employee };
    }

    const isMember = conv.participants.some((p) => String(p) === String(employeeId));
    if (!isMember) return { error: { status: 403, message: 'Not a participant in this conversation' } };
    return { conv, employee };
  };

  const getIntegration = async (_req, res) => {
    try {
      const integration = getChatIntegration(tenantId);
      res.status(200).json({ integration });
    } catch (error) {
      res.status(500).json({ message: 'Error fetching chat integration', error: error?.message });
    }
  };

  const getTeamRoom = async (req, res) => {
    try {
      const { employeeId } = req.query;
      if (!employeeId) {
        return res.status(400).json({ message: 'employeeId is required' });
      }

      const employee = await Employee.findById(employeeId).select('_id name email');
      if (!employee) {
        return res.status(403).json({ message: 'Invalid employee' });
      }

      const conversation = await ensureTeamConversation();
      const unreadCount = await Message.countDocuments({
        conversation: conversation._id,
        sender: { $ne: employeeId },
        readBy: { $not: { $elemMatch: { employee: employeeId } } },
      });

      res.status(200).json({
        conversation: {
          ...conversation.toObject(),
          unreadCount,
        },
        currentUser: employee,
      });
    } catch (error) {
      res.status(500).json({ message: 'Error fetching team chat', error: error?.message });
    }
  };

  const getConversations = async (req, res) => {
    try {
      const { employeeId } = req.query;
      if (!employeeId) {
        return res.status(400).json({ message: 'employeeId is required' });
      }

      const conversation = await ensureTeamConversation();
      const unreadCount = await Message.countDocuments({
        conversation: conversation._id,
        sender: { $ne: employeeId },
        readBy: { $not: { $elemMatch: { employee: employeeId } } },
      });

      res.status(200).json({
        conversations: [
          {
            ...conversation.toObject(),
            title: conversation.title || 'Team Chat',
            unreadCount,
          },
        ],
      });
    } catch (error) {
      res.status(500).json({ message: 'Error fetching conversations', error: error?.message });
    }
  };

  const createOrGetConversation = async (req, res) => {
    try {
      const { employeeId, peerId } = req.body;
      if (!employeeId || !peerId) {
        return res.status(400).json({ message: 'employeeId and peerId are required' });
      }
      if (String(employeeId) === String(peerId)) {
        return res.status(400).json({ message: 'Cannot start a chat with yourself' });
      }

      const peer = await Employee.findById(peerId).select('name email department');
      if (!peer) {
        return res.status(404).json({ message: 'Peer employee not found' });
      }

      const participantKey = buildDirectParticipantKey(employeeId, peerId);
      let conversation = await Conversation.findOne({ participantKey })
        .populate('participants', 'name email department')
        .populate('lastMessageSender', 'name');

      if (!conversation) {
        conversation = await Conversation.create({
          type: 'direct',
          participants: [employeeId, peerId],
          participantKey,
          lastMessageAt: new Date(),
        });
        conversation = await Conversation.findById(conversation._id)
          .populate('participants', 'name email department')
          .populate('lastMessageSender', 'name');
      }

      res.status(200).json({
        conversation: {
          ...conversation.toObject(),
          peer,
        },
      });
    } catch (error) {
      res.status(500).json({ message: 'Error creating conversation', error: error?.message });
    }
  };

  const getMessages = async (req, res) => {
    try {
      const { id } = req.params;
      const { employeeId, after, day = 'today', limit = 200 } = req.query;
      if (!employeeId) {
        return res.status(400).json({ message: 'employeeId is required' });
      }

      const { error } = await assertCanAccess(id, employeeId);
      if (error) return res.status(error.status).json({ message: error.message });

      const filter = { conversation: id };
      let responseDay = null;
      let hasOlder = false;

      if (after) {
        const afterDate = new Date(after);
        if (!Number.isNaN(afterDate.getTime())) {
          filter.createdAt = { $gt: afterDate };
        }
      } else {
        const { start, end, dayKey } = getDayBoundaries(day);
        responseDay = dayKey;
        filter.createdAt = { $gte: start, $lte: end };
        hasOlder = Boolean(
          await Message.exists({
            conversation: id,
            createdAt: { $lt: start },
          })
        );
      }

      const messages = await Message.find(filter)
        .sort({ createdAt: 1 })
        .limit(Math.min(Number(limit) || 200, 300))
        .populate('sender', 'name email department')
        .populate('mentions.employee', 'name email')
        .populate('poll.options.votes.employee', 'name')
        .lean();

      if (after) {
        res.status(200).json({ messages });
        return;
      }

      res.status(200).json({
        messages,
        day: responseDay,
        hasOlder,
      });
    } catch (error) {
      res.status(500).json({ message: 'Error fetching messages', error: error?.message });
    }
  };

  const sendMessage = async (req, res) => {
    try {
      const { id } = req.params;
      const { employeeId, body, mentions } = req.body;
      if (!employeeId || !body?.trim()) {
        return res.status(400).json({ message: 'employeeId and body are required' });
      }

      const { error, conv, employee } = await assertCanAccess(id, employeeId);
      if (error) return res.status(error.status).json({ message: error.message });

      const normalizedMentions = normalizeMentions(mentions);

      const message = await Message.create({
        conversation: id,
        sender: employee._id,
        body: body.trim(),
        mentions: normalizedMentions,
        readBy: [{ employee: employee._id, readAt: new Date() }],
      });

      await Conversation.findByIdAndUpdate(conv._id, {
        lastMessageAt: new Date(),
        lastMessagePreview: previewText(body),
        lastMessageSender: employee._id,
      });

      const populated = await Message.findById(message._id)
        .populate('sender', 'name email department')
        .populate('mentions.employee', 'name email')
        .lean();

      res.status(201).json({ message: populated });
    } catch (error) {
      res.status(500).json({ message: 'Error sending message', error: error?.message });
    }
  };

  const createPoll = async (req, res) => {
    try {
      const { id } = req.params;
      const { employeeId, question, options, allowMultiple = false } = req.body;
      if (!employeeId || !question?.trim()) {
        return res.status(400).json({ message: 'employeeId and question are required' });
      }

      const cleanedOptions = (Array.isArray(options) ? options : [])
        .map((opt) => String(opt || '').trim())
        .filter(Boolean);

      if (cleanedOptions.length < 2) {
        return res.status(400).json({ message: 'At least 2 poll options are required' });
      }
      if (cleanedOptions.length > 10) {
        return res.status(400).json({ message: 'Maximum 10 poll options allowed' });
      }

      const { error, conv, employee } = await assertCanAccess(id, employeeId);
      if (error) return res.status(error.status).json({ message: error.message });

      const pollOptions = cleanedOptions.map((text) => ({ text, votes: [] }));
      const trimmedQuestion = question.trim();

      const message = await Message.create({
        conversation: id,
        sender: employee._id,
        messageType: 'poll',
        body: trimmedQuestion,
        poll: {
          question: trimmedQuestion,
          options: pollOptions,
          allowMultiple: Boolean(allowMultiple),
        },
        readBy: [{ employee: employee._id, readAt: new Date() }],
      });

      await Conversation.findByIdAndUpdate(conv._id, {
        lastMessageAt: new Date(),
        lastMessagePreview: previewText(`Poll: ${trimmedQuestion}`),
        lastMessageSender: employee._id,
      });

      const populated = await Message.findById(message._id)
        .populate('sender', 'name email department')
        .populate('poll.options.votes.employee', 'name')
        .lean();

      res.status(201).json({ message: populated });
    } catch (error) {
      res.status(500).json({ message: 'Error creating poll', error: error?.message });
    }
  };

  const votePoll = async (req, res) => {
    try {
      const { messageId } = req.params;
      const { employeeId, optionIndex } = req.body;
      if (!employeeId || optionIndex === undefined || optionIndex === null) {
        return res.status(400).json({ message: 'employeeId and optionIndex are required' });
      }

      const index = Number(optionIndex);
      if (!Number.isInteger(index) || index < 0) {
        return res.status(400).json({ message: 'Invalid optionIndex' });
      }

      const message = await Message.findById(messageId);
      if (!message || message.messageType !== 'poll' || !message.poll) {
        return res.status(404).json({ message: 'Poll not found' });
      }

      const { error } = await assertCanAccess(message.conversation, employeeId);
      if (error) return res.status(error.status).json({ message: error.message });

      if (!message.poll.options[index]) {
        return res.status(400).json({ message: 'Invalid poll option' });
      }

      const now = new Date();
      const employeeKey = String(employeeId);

      if (!message.poll.allowMultiple) {
        message.poll.options.forEach((opt) => {
          opt.votes = opt.votes.filter((v) => String(v.employee) !== employeeKey);
        });
        message.poll.options[index].votes.push({ employee: employeeId, votedAt: now });
      } else {
        const option = message.poll.options[index];
        const existingIdx = option.votes.findIndex((v) => String(v.employee) === employeeKey);
        if (existingIdx >= 0) {
          option.votes.splice(existingIdx, 1);
        } else {
          option.votes.push({ employee: employeeId, votedAt: now });
        }
      }

      await message.save();

      const populated = await Message.findById(message._id)
        .populate('sender', 'name email department')
        .populate('poll.options.votes.employee', 'name')
        .lean();

      res.status(200).json({ message: populated });
    } catch (error) {
      res.status(500).json({ message: 'Error voting on poll', error: error?.message });
    }
  };

  const markConversationRead = async (req, res) => {
    try {
      const { id } = req.params;
      const { employeeId } = req.body;
      if (!employeeId) {
        return res.status(400).json({ message: 'employeeId is required' });
      }

      const { error } = await assertCanAccess(id, employeeId);
      if (error) return res.status(error.status).json({ message: error.message });

      const unread = await Message.find({
        conversation: id,
        sender: { $ne: employeeId },
        readBy: { $not: { $elemMatch: { employee: employeeId } } },
      });

      const now = new Date();
      await Promise.all(
        unread.map((msg) => {
          msg.readBy.push({ employee: toObjectId(employeeId), readAt: now });
          return msg.save();
        })
      );

      res.status(200).json({ marked: unread.length });
    } catch (error) {
      res.status(500).json({ message: 'Error marking conversation read', error: error?.message });
    }
  };

  const getChatEmployees = async (req, res) => {
    try {
      const { search = '' } = req.query;
      const filter = {};
      if (search.trim()) {
        const q = search.trim();
        filter.$or = [
          { name: { $regex: q, $options: 'i' } },
          { email: { $regex: q, $options: 'i' } },
          { department: { $regex: q, $options: 'i' } },
        ];
      }

      const employees = await Employee.find(filter)
        .select('name email department')
        .sort({ name: 1 })
        .limit(100)
        .lean();

      res.status(200).json({ employees });
    } catch (error) {
      res.status(500).json({ message: 'Error fetching employees', error: error?.message });
    }
  };

  return {
    getIntegration,
    getTeamRoom,
    getConversations,
    createOrGetConversation,
    getMessages,
    sendMessage,
    createPoll,
    votePoll,
    markConversationRead,
    getChatEmployees,
  };
};
