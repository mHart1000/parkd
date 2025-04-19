<template>
  <q-page class="q-pa-lg flex flex-center">
    <div class="dashboard-wrapper">
      <div class="text-h5 q-mb-md">Dashboard</div>

      <q-card class="q-pa-md">
        <q-card-section>
          Map here
        </q-card-section>
        <q-card-section>
        </q-card-section>
      </q-card>
      <q-btn class="q-mt-md" label="Log Out" color="negative" @click="logout" />
    </div>
  </q-page>
</template>

<script>
import { Notify } from 'quasar'
import { Geolocation } from '@capacitor/geolocation'

export default {
  name: 'DashboardPage',
  data () {
    return {
      lat: 51.505,
      lng: -0.09,
      map: null
    }
  },
  methods: {
    logout () {
      // Clear JWT token from localStorage
      localStorage.removeItem('token')

      // Optionally remove Authorization header from Axios
      this.$api.defaults.headers.common.Authorization = ''

      // Notify user and redirect to login
      Notify.create({ type: 'positive', message: 'You have been logged out!' })
      this.$router.push('/login')
    },
    async getLocation () {
      try {
        const coordinates = await Geolocation.getCurrentPosition()
        this.lat = coordinates.coords.latitude
        this.lng = coordinates.coords.longitude
        const location = {
          latitude: this.lat,
          longitude: this.lng
        }
        localStorage.setItem('location', JSON.stringify(location))
        console.log('Current position:', coordinates)
        console.log(coordinates)
      } catch (error) {
        console.error('Error getting location:', error)
      }
    }
  },
  mounted () {
    this.getLocation()
    this.initMap()
  }
}
</script>

<style scoped>
</style>
