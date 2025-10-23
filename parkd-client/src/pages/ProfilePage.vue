<template>
  <q-page class="q-pa-md">
    <q-card>
      <q-card-section>
        <div class="text-h6">Your Profile</div>
      </q-card-section>
      <q-card-section>
        <q-input v-model="profile.first_name" label="First Name" />
        <q-input v-model="profile.last_name" label="Last Name" />
        <q-input v-model="profile.bio" label="Bio" type="textarea" />
        <q-input v-model="profile.avatar_url" label="Avatar URL" />
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
import axios from 'axios'

export default {
  name: 'ProfilePage',
  setup () {
    const $q = useQuasar()
    const profile = ref({ first_name: '', last_name: '', bio: '', avatar_url: '' })

    const fetchProfile = async () => {
      const res = await axios.get('/api/profile')
      profile.value = res.data
    }

    const updateProfile = async () => {
      try {
        await axios.put('/api/profile', { profile: profile.value })
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
