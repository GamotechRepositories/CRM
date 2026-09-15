import axios from 'axios'

// In dev, use Vite proxy (`/api` → backend) to avoid browser CORS issues.
// In production, set VITE_API_URL to your deployed API root.
const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api/v1/admin',
})

api.interceptors.request.use((config) => {
  try {
    const token = localStorage.getItem('central_admin_token')
    if (token) {
      config.headers = config.headers || {}
      config.headers.Authorization = `Bearer ${token}`
    }
  } catch {
    /* ignore */
  }
  return config
})

export default api
