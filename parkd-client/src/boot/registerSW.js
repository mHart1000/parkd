import axios from 'axios'

export default async () => {
  if (!('serviceWorker' in navigator && 'PushManager' in window)) return

  try {
    const reg = await navigator.serviceWorker.register('/service-worker.js')
    const permission = await Notification.requestPermission()
    if (permission !== 'granted') return

    const subscription = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(import.meta.env.VITE_VAPID_PUBLIC_KEY)
    })

    await axios.post(`${import.meta.env.VITE_API_BASE_URL}/api/push_subscriptions`, subscription)

  } catch (err) {
    console.error('Service worker registration or subscription failed', err)
  }
}

function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const raw = window.atob(base64)
  const output = new Uint8Array(raw.length)
  for (let i = 0; i < raw.length; ++i) output[i] = raw.charCodeAt(i)
  return output
}
