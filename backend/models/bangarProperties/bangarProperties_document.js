import mongoose from 'mongoose';
import { getDocumentFields } from '../../utils/documentFields.js';

const documentSchema = new mongoose.Schema(getDocumentFields('bangarProperties'), { timestamps: true });

const Document = mongoose.model('bangarProperties_Document', documentSchema);
export default Document;
