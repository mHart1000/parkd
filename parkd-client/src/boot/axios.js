import { boot } from 'quasar/wrappers'
import axios from 'axios'

const api = axios.create({
  baseURL: 'http://localhost:3000/api'
})

api.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
}, error => {
  return Promise.reject(error)
})

export default boot(({ app }) => {
  // Make Axios globally available in your Vue components
  app.config.globalProperties.$axios = axios // Default Axios instance
  app.config.globalProperties.$api = api // Custom API instance
})

export { axios, api }
