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
        console.log('Login successful!', response.data)
      } catch (error) {
        console.error('Login failed:', error.response?.data || error.message)
      }
    }
  }
}
</script>
