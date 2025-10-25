<template>
  <q-page class="row items-center justify-center" style="min-height: 100vh;">
    <q-card style="max-width:420px; width: 100%;" class="q-pa-md">
      <q-card-section>
        <div class="text-h6">Profile</div>
      </q-card-section>
      <q-card-section>
        <q-input v-model="profile.name" label="Name" />
        <q-item class="q-px-none q-mt-md">
          <q-item-section>
            <q-item-label caption>Email</q-item-label>
            <q-item-label class="text-grey-7">{{ profile.email }}</q-item-label>
          </q-item-section>
        </q-item>
      </q-card-section>
      <q-card-actions align="right">
        <q-btn color="primary" label="Save" @click="updateProfile" />
      </q-card-actions>
    </q-card>
  </q-page>
</template>

<script>
import { ref, onMounted } from 'vue'
import { useQuasar } from 'quasar'
import { api } from 'src/boot/axios'

export default {
  name: 'ProfilePage',
  setup () {
    const profile = ref({ name: '', email: '' })
    const $q = useQuasar()

    const fetchProfile = async () => {
      const res = await api.get('/user/')
      console.log('Profile data fetched:', res.data)
      profile.value = res.data
    }

    const updateProfile = async () => {
      try {
        await api.put('/user', { user: profile.value })
        $q.notify({ type: 'positive', message: 'Profile updated!' })
      } catch (err) {
        $q.notify({ type: 'negative', message: 'Error saving profile' })
      }
    }
    onMounted(fetchProfile)

    return { profile, updateProfile }
  }
}
</script>
