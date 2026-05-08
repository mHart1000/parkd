<template>
  <q-page class="row items-center justify-center" style="min-height: 100vh;">
    <q-card style="max-width:420px; width: 100%;" class="q-pa-md">
      <q-card-section>
        <div class="text-h6 q-mb-md">Create account</div>

        <q-form @submit="registerUser" class="q-gutter-md">
          <q-input
            v-model="name"
            label="Name"
            dense
            clearable
            borderless
            autofocus
          />

          <q-input
            v-model="email"
            label="Email"
            type="email"
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

          <q-input
            v-model="passwordConfirmation"
            :type="showConfirm ? 'text' : 'password'"
            label="Confirm password"
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
                :icon="showConfirm ? 'visibility_off' : 'visibility'"
                @click="showConfirm = !showConfirm"
                :aria-label="showConfirm ? 'Hide password confirmation' : 'Show password confirmation'"
              />
            </template>
          </q-input>
        </q-form>
      </q-card-section>
      <div class="text-center q-mt-md">
        Already have an account? <router-link to="/login" class="text-primary">Sign in</router-link>
      </div>
      <q-card-actions align="right" class="q-pa-sm">
        <q-btn label="Register" color="primary" @click="registerUser" />
      </q-card-actions>
    </q-card>
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
      passwordConfirmation: '',
      showPassword: false,
      showConfirm: false
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
:deep(.q-field__control) {
  background-color: #68a3ab;
  border-radius: 2px;
  color: #2c2c2c;
}

:deep(.q-field__label) {
  color: #2b2b2b !important;
}

</style>
