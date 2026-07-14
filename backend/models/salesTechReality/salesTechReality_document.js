import mongoose from 'mongoose';
import { getDocumentFields } from '../../utils/documentFields.js';

const documentSchema = new mongoose.Schema(getDocumentFields('salesTechReality'), { timestamps: true });

const Document = mongoose.model('salesTechReality_Document', documentSchema);
export default Document;
