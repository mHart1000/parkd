<template>
  <q-page>
    <q-form @submit="loginUser" class="q-pa-md">
      <q-input v-model="email" label="Email" type="email" />
      <q-input v-model="password" label="Password" type="password" />
      <q-btn label="Login" type="submit" color="primary" />
    </q-form>
  </q-page>
</template>

<script>
import { Notify } from 'quasar'

export default {
  name: 'LoginPage',
  data () {
    return {
      email: '',
      password: ''
    }
  },
  methods: {
    async loginUser () {
      try {
        const response = await this.$api.post('/users/sign_in', {
          user: {
            email: this.email,
            password: this.password
          }
        })

        // Store the JWT token in localStorage
        const token = response.data.token
        localStorage.setItem('token', token)

        // Set the token in Axios for future requests
        this.$api.defaults.headers.common.Authorization = `Bearer ${token}`

        // Notify user and redirect
        Notify.create({ type: 'positive', message: 'Login successful!' })
        this.$router.push('/dashboard') // Redirect to a protected page
      } catch (error) {
        Notify.create({ type: 'negative', message: 'Login failed. Please check your credentials.' })
        console.error('Login error:', error.response?.data || error.message)
      }
    }
  }
}
</script>
