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
        <q-select
          v-model="profile.notification_lead_time_hours"
          :options="leadTimeOptions"
          emit-value
          map-options
          label="Notification lead time"
          class="q-mt-md"
        />
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
    const profile = ref({
      name: '',
      email: '',
      notification_lead_time_hours: null
    })
    const $q = useQuasar()

    const leadTimeOptions = [
      { label: '1 hour before', value: 1 },
      { label: '3 hours before', value: 3 },
      { label: '6 hours before', value: 6 },
      { label: '12 hours before', value: 12 },
      { label: '24 hours before', value: 24 }
    ]

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

    return { profile, updateProfile, leadTimeOptions }
  }
}
</script>
