<template>
  <q-page class="row items-center justify-center" style="min-height: 100vh;">
    <q-card style="max-width:420px; width: 100%;" class="q-pa-md">
      <q-card-section>
        <div class="text-h6 q-mb-md">Sign in</div>

        <q-form @submit="loginUser" class="q-gutter-md">
          <q-input
            v-model="email"
            label="Email"
            type="email"
            autofocus
            dense
            clearable
            borderless
          />

          <q-input
            v-model="password"
            :type="showPassword ? 'text' : 'password'"
            label="Password"
            dense
            clearable
            borderless
          >
            <template v-slot:append>
              <q-btn
                dense
                flat
                round
                size="sm"
                :icon="showPassword ? 'visibility_off' : 'visibility'"
                @click="showPassword = !showPassword"
                :aria-label="showPassword ? 'Hide password' : 'Show password'"
              />
            </template>
          </q-input>
        </q-form>
      </q-card-section>
      <div class="text-center q-mt-md">
        Don't have an account? <router-link to="/register" class="text-primary">Sign up</router-link>
      </div>
      <q-card-actions align="right" class="q-pa-sm">
        <q-btn label="Login" color="primary" @click="loginUser" />
      </q-card-actions>
    </q-card>
  </q-page>
</template>

<script>
import { Notify } from 'quasar'
import { secureStorage } from 'src/utils/secureStorage'
import { registerPushNotifications } from 'src/boot/registerSW'

export default {
  name: 'LoginPage',
  data () {
    return {
      email: '',
      password: '',
      showPassword: false
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

        const token = response.data.token
        await secureStorage.setToken(token)

        await registerPushNotifications()

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

<style scoped>
:deep(.q-field__control) {
  background-color: #68a3ab;
  border-radius: 2px;
  color: #2c2c2c;
}

:deep(.q-field__label) {
  color: #2b2b2b !important;
}
</style>
