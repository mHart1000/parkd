<template>
  <q-page padding>
    <div class="text-h5 q-mb-md">Welcome to Your Dashboard</div>
    <q-btn label="Log Out" color="negative" @click="logout" />
  </q-page>
</template>

<script>
import { Notify } from 'quasar'

export default {
  name: 'DashboardPage',
  methods: {
    logout () {
      // Clear JWT token from localStorage
      localStorage.removeItem('token')

      // Optionally remove Authorization header from Axios
      this.$api.defaults.headers.common['Authorization'] = ''

      // Notify user and redirect to login
      Notify.create({ type: 'positive', message: 'You have been logged out!' })
      this.$router.push('/login')
    }
  }
}
</script>

<style scoped>
</style>
