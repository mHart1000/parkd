import { boot } from 'quasar/wrappers'
import axios from 'axios'
import { secureStorage } from 'src/utils/secureStorage'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api'
})

// Add Authorization header from secure storage
api.interceptors.request.use(async config => {
  const token = await secureStorage.getToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
}, error => {
  return Promise.reject(error)
})

// Handle 401 responses - clear token
api.interceptors.response.use(
  response => response,
  async error => {
    if (error.response?.status === 401) {
      await secureStorage.removeToken()
    }
    return Promise.reject(error)
  }
)

export default boot(({ app }) => {
  // Make Axios globally available in your Vue components
  app.config.globalProperties.$axios = axios // Default Axios instance
  app.config.globalProperties.$api = api // Custom API instance
})

export { axios, api }
