import api from '../api/axios'

/**
 * Upload a File directly to S3 (presigned PUT).
 * Only a tiny JSON request goes through the API — file bytes never hit the server (avoids 413).
 * @param {File} file
 * @param {{ folder?: string, proxyFallback?: boolean }} [options]
 * @returns {Promise<{ url: string, fileName: string, mimeType: string, size: number, key: string, folder: string }>}
 */
export async function uploadFile(file, options = {}) {
  if (!file) throw new Error('File is required')
  const folder = options.folder || 'misc'
  const mimeType = file.type || 'application/octet-stream'

  const { data } = await api.post('/uploads/presign', {
    fileName: file.name,
    mimeType,
    folder,
    size: file.size || 0,
  })

  const uploadUrl = data?.uploadUrl
  if (!uploadUrl) throw new Error(data?.message || 'Failed to get upload URL')

  const contentType = data?.headers?.['Content-Type'] || mimeType
  try {
    const putRes = await fetch(uploadUrl, {
      method: 'PUT',
      headers: { 'Content-Type': contentType },
      body: file,
    })
    if (!putRes.ok) {
      const detail = await putRes.text().catch(() => '')
      throw new Error(detail?.slice(0, 200) || `Direct S3 upload failed (${putRes.status})`)
    }
  } catch (directError) {
    // Small signature images can use the API if the browser cannot PUT to S3.
    if (!options.proxyFallback || file.size > 5 * 1024 * 1024) throw directError
    const form = new FormData()
    form.append('file', file)
    form.append('folder', folder)
    const { data: uploaded } = await api.post('/uploads', form)
    const url = uploaded?.url || uploaded?.documentUrl
    if (!url) throw new Error('Upload completed without an image URL. Please try again.')
    return { ...uploaded, url }
  }

  if (!data?.url && !data?.documentUrl) throw new Error('Upload completed without an image URL. Please try again.')

  return {
    url: data?.url || data?.documentUrl,
    fileName: data?.fileName || file.name,
    mimeType: data?.mimeType || mimeType,
    size: data?.size || file.size || 0,
    key: data?.key || '',
    folder: data?.folder || folder,
  }
}
