import mongoose from 'mongoose';
import { getDocumentFields } from '../../utils/documentFields.js';

const documentSchema = new mongoose.Schema(getDocumentFields('adsResearchGlobal'), { timestamps: true });

const Document = mongoose.model('adsResearchGlobal_Document', documentSchema);
export default Document;
