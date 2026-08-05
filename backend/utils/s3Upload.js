import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

let cachedClient = null;

export const UPLOAD_FOLDERS = [
  'documents',
  'chat',
  'photos',
  'logos',
  'signatures',
  'quotations',
  'evidence',
  'social',
  'profiles',
  'misc',
];

const requiredEnv = (name) => {
  const value = String(process.env[name] || '').trim();
  if (!value) {
    const err = new Error(`Missing required environment variable: ${name}`);
    err.statusCode = 500;
    throw err;
  }
  return value;
};

const sanitizeFileName = (name = '') =>
  String(name || 'file')
    .replace(/\s+/g, '-')
    .replace(/[^a-zA-Z0-9._-]/g, '')
    .slice(-120) || 'file';

const sanitizeFolder = (folder = 'misc') => {
  const value = String(folder || 'misc').trim().toLowerCase();
  return UPLOAD_FOLDERS.includes(value) ? value : 'misc';
};

const getS3Client = () => {
  if (cachedClient) return cachedClient;
  cachedClient = new S3Client({
    region: requiredEnv('AWS_REGION'),
    credentials: {
      accessKeyId: requiredEnv('AWS_ACCESS_KEY_ID'),
      secretAccessKey: requiredEnv('AWS_SECRET_ACCESS_KEY'),
    },
  });
  return cachedClient;
};

/** Public URL stored in DB — prefers CloudFront when AWS_CLOUDFRONT_URL is set. */
export const buildPublicFileUrl = (key) => {
  const cloudfront = String(process.env.AWS_CLOUDFRONT_URL || '').trim().replace(/\/+$/, '');
  if (cloudfront) return `${cloudfront}/${key}`;

  const region = requiredEnv('AWS_REGION');
  const bucket = requiredEnv('AWS_BUCKET_NAME');
  return `https://${bucket}.s3.${region}.amazonaws.com/${key}`;
};

/** Upload any file buffer to the tenant's S3 prefix. */
export const uploadFileToS3 = async ({
  fileBuffer,
  originalName,
  mimeType,
  tenantKey = 'common',
  folder = 'misc',
}) => {
  if (!fileBuffer || !fileBuffer.length) {
    const err = new Error('File is required');
    err.statusCode = 400;
    throw err;
  }

  const bucket = requiredEnv('AWS_BUCKET_NAME');
  const safeFolder = sanitizeFolder(folder);
  const key = `${tenantKey}/${safeFolder}/${Date.now()}-${sanitizeFileName(originalName)}`;

  await getS3Client().send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: fileBuffer,
      ContentType: mimeType || 'application/octet-stream',
    })
  );

  return {
    key,
    folder: safeFolder,
    url: buildPublicFileUrl(key),
  };
};

/** @deprecated Prefer uploadFileToS3 */
export const uploadDocumentToS3 = (args) =>
  uploadFileToS3({ ...args, folder: args?.folder || 'documents' });
