import { uploadFileToS3 } from './s3Upload.js';

const getError = (error, fallback) => {
  if (!error) return { status: 500, message: fallback };
  if (error.statusCode) return { status: error.statusCode, message: error.message || fallback };
  if (error.name === 'MulterError') {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return { status: 400, message: 'File is too large. Max 25 MB.' };
    }
    return { status: 400, message: error.message || fallback };
  }
  return { status: 500, message: error.message || fallback };
};

/**
 * Shared upload handlers for all CRM tenants.
 * Mount as POST /uploads (and optionally POST /documents/upload).
 */
export const createUploadHandlers = ({ tenantKey = 'common' } = {}) => {
  const uploadFile = async (req, res) => {
    try {
      if (!req.file) return res.status(400).json({ message: 'File is required' });

      const folder = req.body?.folder || req.query?.folder || 'misc';
      const uploaded = await uploadFileToS3({
        fileBuffer: req.file.buffer,
        originalName: req.file.originalname,
        mimeType: req.file.mimetype,
        tenantKey,
        folder,
      });

      res.status(201).json({
        message: 'File uploaded successfully',
        url: uploaded.url,
        documentUrl: uploaded.url,
        fileName: req.file.originalname,
        mimeType: req.file.mimetype || '',
        size: req.file.size || 0,
        key: uploaded.key,
        folder: uploaded.folder,
      });
    } catch (error) {
      const { status, message } = getError(error, 'Error uploading file');
      res.status(status).json({ message });
    }
  };

  return { uploadFile };
};
