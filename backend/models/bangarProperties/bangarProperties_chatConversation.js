import mongoose from 'mongoose';
import { getChatConversationFields } from '../../utils/chat/chatFields.js';

const companyPrefix = 'bangarProperties';

const conversationSchema = new mongoose.Schema(
  {
    ...getChatConversationFields(companyPrefix),
  },
  { timestamps: true }
);

conversationSchema.index({ participants: 1, lastMessageAt: -1 });

const Conversation = mongoose.model(`${companyPrefix}_ChatConversation`, conversationSchema);

export default Conversation;
