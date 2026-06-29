import Conversation from '../../models/salesTechReality/salesTechReality_chatConversation.js';
import Message from '../../models/salesTechReality/salesTechReality_chatMessage.js';
import Employee from '../../models/salesTechReality/salesTechReality_employee.js';
import { createChatHandlers } from '../../utils/chat/createChatHandlers.js';
import { getChatIntegration } from '../../config/chatIntegrations.js';

const tenantId = 'salesTechReality';

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
