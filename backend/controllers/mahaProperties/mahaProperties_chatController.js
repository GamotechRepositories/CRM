import Conversation from '../../models/mahaProperties/mahaProperties_chatConversation.js';
import Message from '../../models/mahaProperties/mahaProperties_chatMessage.js';
import Employee from '../../models/mahaProperties/mahaProperties_employee.js';
import { createChatHandlers } from '../../utils/chat/createChatHandlers.js';
import { getChatIntegration } from '../../config/chatIntegrations.js';

const tenantId = 'mahaProperties';

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
