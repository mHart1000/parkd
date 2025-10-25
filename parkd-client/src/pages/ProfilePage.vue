<template>
  <q-page class="q-pa-md">
    <q-card>
      <q-card-section>
        <div class="text-h6">Profile</div>
      </q-card-section>
      <q-card-section>
        <q-input v-model="profile.name" label="Name" :disable />
        <q-input v-model="profile.email" label="Email" :disable />
      </q-card-section>
    </q-card>
  </q-page>
</template>

<script>
import { ref, onMounted } from 'vue'
import { api } from 'src/boot/axios'

export default {
  name: 'ProfilePage',
  setup () {
    const profile = ref({ name: '', email: '' })

    const fetchProfile = async () => {
      const res = await api.get('/user/')
      console.log('Profile data fetched:', res.data)
      profile.value = res.data
    }

    onMounted(fetchProfile)

    return { profile }
  }
}
</script>
