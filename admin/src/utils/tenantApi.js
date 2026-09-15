import axios from 'axios'

export const getApiRoot = () => {
  const adminBase = import.meta.env.VITE_API_URL || '/api/v1/admin'
  return String(adminBase).replace(/\/admin\/?$/, '')
}

export const createTenantClient = (tenantId) =>
  axios.create({
    baseURL: `${getApiRoot()}/${tenantId}`,
  })
