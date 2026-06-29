import Conversation from '../../models/adsResearchGlobal/adsResearchGlobal_chatConversation.js';
import Message from '../../models/adsResearchGlobal/adsResearchGlobal_chatMessage.js';
import Employee from '../../models/adsResearchGlobal/adsResearchGlobal_employee.js';
import { createChatHandlers } from '../../utils/chat/createChatHandlers.js';
import { getChatIntegration } from '../../config/chatIntegrations.js';

const tenantId = 'adsResearchGlobal';

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
