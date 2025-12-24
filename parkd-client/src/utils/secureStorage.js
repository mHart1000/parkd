import { Capacitor } from '@capacitor/core'
import { SecureStoragePlugin } from 'capacitor-secure-storage-plugin'

// Secure storage helper:
// handles dev token storage and error handles missing token

export const secureStorage = {
  async setToken (token) {
    if (Capacitor.isNativePlatform()) {
      await SecureStoragePlugin.set({ key: 'auth_token', value: token })
    } else {
      // browser: dev only
      localStorage.setItem('auth_token', token)
    }
  },

  async getToken () {
    if (Capacitor.isNativePlatform()) {
      try {
        const { value } = await SecureStoragePlugin.get({ key: 'auth_token' })
        return value
      } catch (error) {
        // suppress "key not found" errors
        if (error.message?.includes('not exist') || error.code === 'ERR_NO_VALUE') {
          return null
        }
        throw error
      }
    } else {
      return localStorage.getItem('auth_token')
    }
  },

  async removeToken () {
    if (Capacitor.isNativePlatform()) {
      try {
        await SecureStoragePlugin.remove({ key: 'auth_token' })
      } catch (error) {
        if (error.message?.includes('not exist') || error.code === 'ERR_NO_VALUE') {
          return
        }
        throw error
      }
    } else {
      localStorage.removeItem('auth_token')
    }
  }
}
