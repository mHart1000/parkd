<template>
  <q-page>
    <q-form @submit="registerUser" class="q-pa-md">
      <q-input v-model="name" label="Name" />
      <q-input v-model="email" label="Email" type="email" />
      <q-input v-model="password" label="Password" type="password" />
      <q-input v-model="passwordConfirmation" label="Confirm Password" type="password" />
      <q-btn label="Register" type="submit" color="primary" />
    </q-form>
  </q-page>
</template>

<script>
import { Notify } from 'quasar'

export default {
  name: 'RegisterPage',
  data () {
    return {
      name: '',
      email: '',
      password: '',
      passwordConfirmation: ''
    }
  },
  methods: {
    async registerUser () {
      try {
        const response = await this.$api.post('/users', {
          user: {
            name: this.name,
            email: this.email,
            password: this.password,
            password_confirmation: this.passwordConfirmation
          }
        })
        console.log('Server response:', response)
        Notify.create({
          type: 'positive',
          message: 'Registration successful! Please log in.'
        })
        this.$router.push('/login')
      } catch (error) {
        Notify.create({
          type: 'negative',
          message: error.response?.data?.message || 'Registration failed. Please try again.'
        })
        console.error('Registration error:', error.response?.data || error.message)
      }
    }
  }
}
</script>
