import mongoose from 'mongoose';
import { getChatMessageFields } from '../../utils/chat/chatFields.js';

const companyPrefix = 'mahaProperties';

const messageSchema = new mongoose.Schema(
  {
    ...getChatMessageFields(companyPrefix),
  },
  { timestamps: true }
);

messageSchema.index({ conversation: 1, createdAt: 1 });

const Message = mongoose.model(`${companyPrefix}_ChatMessage`, messageSchema);

export default Message;
