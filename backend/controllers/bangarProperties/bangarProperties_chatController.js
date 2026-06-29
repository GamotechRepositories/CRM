import Conversation from '../../models/bangarProperties/bangarProperties_chatConversation.js';
import Message from '../../models/bangarProperties/bangarProperties_chatMessage.js';
import Employee from '../../models/bangarProperties/bangarProperties_employee.js';
import { createChatHandlers } from '../../utils/chat/createChatHandlers.js';
import { getChatIntegration } from '../../config/chatIntegrations.js';

const tenantId = 'bangarProperties';

export const {
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
} = createChatHandlers({
  Conversation,
  Message,
  Employee,
  tenantId,
  getChatIntegration,
});
