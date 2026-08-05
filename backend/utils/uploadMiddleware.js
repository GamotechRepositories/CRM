import multer from 'multer';

const storage = multer.memoryStorage();

/** Shared multipart parser for documents, chat, photos, logos, etc. */
export const mediaUpload = multer({
  storage,
  limits: {
    fileSize: 25 * 1024 * 1024,
  },
});

/** @deprecated Prefer mediaUpload */
export const documentUpload = mediaUpload;
