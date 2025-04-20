<template>
  <q-page class="q-pa-lg flex flex-center">
    <div class="dashboard-wrapper">
      <div class="text-h5 q-mb-md">Dashboard</div>

      <q-card class="q-pa-md">
        <q-card-section>
          <LeafletMap />
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
import LeafletMap from 'components/LeafletMap.vue'

export default {
  name: 'DashboardPage',
  components: {
    LeafletMap
  },
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
    }
  }
}
</script>

<style scoped>
</style>
