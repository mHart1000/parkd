import { boot } from 'quasar/wrappers'
import axios from 'axios'
import { secureStorage } from 'src/utils/secureStorage'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api'
})

api.interceptors.request.use(async config => {
  const token = await secureStorage.getToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
}, error => {
  return Promise.reject(error)
})

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
  app.config.globalProperties.$axios = axios
  app.config.globalProperties.$api = api
})

export { axios, api }
