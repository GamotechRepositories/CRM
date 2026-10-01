import api from '../api/axios'

/**
 * Upload a File directly to S3 (presigned PUT), with dataUrl fallback.
 * @param {File} file
 * @param {{ folder?: string, tenantId?: string }} [options]
 * @returns {Promise<{ url: string, fileName: string, mimeType: string, size: number, key?: string, folder?: string }>}
 */
export async function uploadFile(file, options = {}) {
  if (!file) throw new Error('File is required')
  const folder = options.folder || 'misc'
  const mimeType = file.type || 'application/octet-stream'
  const tenantId = options.tenantId

  const endpoint = tenantId
    ? `/companies/${tenantId}/uploads/presign`
    : '/uploads/presign'

  try {
    const { data } = await api.post(endpoint, {
      fileName: file.name,
      mimeType,
      folder,
      size: file.size || 0,
    })

    const uploadUrl = data?.uploadUrl
    if (uploadUrl) {
      const contentType = data?.headers?.['Content-Type'] || mimeType
      const putRes = await fetch(uploadUrl, {
        method: 'PUT',
        headers: { 'Content-Type': contentType },
        body: file,
      })

      if (putRes.ok) {
        return {
          url: data?.url || data?.documentUrl || '',
          fileName: data?.fileName || file.name,
          mimeType: data?.mimeType || mimeType,
          size: data?.size || file.size || 0,
          key: data?.key || '',
          folder: data?.folder || folder,
        }
      }
    }
  } catch (err) {
    console.warn('Presigned S3 upload attempt failed, falling back to dataUrl:', err)
  }

  // Fallback to dataUrl so that evidence is never lost
  const dataUrl = await new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result)
    reader.onerror = reject
    reader.readAsDataURL(file)
  })

  return {
    url: dataUrl,
    fileName: file.name,
    mimeType,
    size: file.size || 0,
    folder,
  }
}
