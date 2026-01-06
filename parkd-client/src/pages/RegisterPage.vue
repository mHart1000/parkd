<template>
  <q-page class="flex flex-center">
    <div class="register-card q-pa-lg">
      <div class="text-h5 text-center q-mb-lg">Create Account</div>
      <q-form @submit="registerUser">
        <q-input v-model="name" label="Name" outlined class="q-mb-md" />
        <q-input v-model="email" label="Email" type="email" outlined class="q-mb-md" />
        <q-input v-model="password" label="Password" type="password" outlined class="q-mb-md" />
        <q-input v-model="passwordConfirmation" label="Confirm Password" type="password" outlined class="q-mb-lg" />
        <q-btn label="Register" type="submit" color="dark" class="full-width" unelevated />
      </q-form>
    </div>
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
          message: error.response?.data?.errors?.join(', ') || 'Registration failed. Please try again.'
        })
        console.error('error')
        console.error(error)
        console.error('Registration error:', error.response?.data || error.message)
      }
    }
  }
}
</script>

<style scoped>
.register-card {
  width: 100%;
  max-width: 400px;
}
</style>
