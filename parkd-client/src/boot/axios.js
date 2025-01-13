import { boot } from 'quasar/wrappers'
import axios from 'axios'

const api = axios.create({
  baseURL: 'http://localhost:3000/api', // Your Rails API URL
  withCredentials: true // Allows cookies to be sent (if using session-based auth)
})

export default boot(({ app }) => {
  // Make Axios globally available in your Vue components
  app.config.globalProperties.$axios = axios // Default Axios instance
  app.config.globalProperties.$api = api // Custom API instance
})

export { api }
