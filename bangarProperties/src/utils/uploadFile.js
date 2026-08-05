import api from '../api/axios'

/**
 * Upload a File to S3 via the CRM backend.
 * @param {File} file
 * @param {{ folder?: string }} [options]
 * @returns {Promise<{ url: string, fileName: string, mimeType: string, size: number, key: string, folder: string }>}
 */
export async function uploadFile(file, options = {}) {
  if (!file) throw new Error('File is required')
  const folder = options.folder || 'misc'
  const formData = new FormData()
  formData.append('file', file)
  formData.append('folder', folder)
  const res = await api.post('/uploads', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return {
    url: res.data?.url || res.data?.documentUrl || '',
    fileName: res.data?.fileName || file.name,
    mimeType: res.data?.mimeType || file.type || '',
    size: res.data?.size || file.size || 0,
    key: res.data?.key || '',
    folder: res.data?.folder || folder,
  }
}
