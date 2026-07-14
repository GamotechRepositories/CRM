import mongoose from 'mongoose';
import { getDocumentFields } from '../../utils/documentFields.js';

const documentSchema = new mongoose.Schema(getDocumentFields('mahaProperties'), { timestamps: true });

const Document = mongoose.model('mahaProperties_Document', documentSchema);
export default Document;
