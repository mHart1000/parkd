import { api } from 'src/boot/axios'
import { secureStorage } from 'src/utils/secureStorage'
import { Capacitor } from '@capacitor/core'

export async function registerPushNotifications () {
  if (!('serviceWorker' in navigator && 'PushManager' in window)) {
    console.warn('Push notifications not supported in this browser')
    return false
  }

  try {
    const reg = await navigator.serviceWorker.register('/service-worker.js')
    const permission = await Notification.requestPermission()
    if (permission !== 'granted') {
      console.warn('Push notification permission denied')
      return false
    }

    const subscription = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(import.meta.env.VITE_VAPID_PUBLIC_KEY)
    })

    await api.post('/push_subscriptions', subscription)
    console.log('Push notification subscription registered')
    return true
  } catch (err) {
    console.error('Push notification registration failed', err)
    return false
  }
}

export default async () => {
  // different method for mobile
  if (Capacitor.isNativePlatform()) return

  const token = await secureStorage.getToken()
  if (!token) return

  await registerPushNotifications()
}

function urlBase64ToUint8Array (base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const raw = window.atob(base64)
  const output = new Uint8Array(raw.length)
  for (let i = 0; i < raw.length; ++i) output[i] = raw.charCodeAt(i)
  return output
}
