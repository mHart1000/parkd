<template>
  <q-layout view="lHh Lpr lFf">
    <q-header class="bg-dark-page">

        <q-btn
          flat
          dense
          round
          icon="menu"
          aria-label="Menu"
          @click="toggleLeftDrawer"
        />

    </q-header>

    <q-drawer
      v-model="leftDrawerOpen"
      bordered
    >
      <q-list>
        <q-item-label
          header
        >
          Parkd
        </q-item-label>

        <EssentialLink
          v-for="link in essentialLinks"
          :key="link.title"
          v-bind="link"
        />

        <q-separator class="q-my-md" />

        <q-item clickable @click="logout">
          <q-item-section avatar>
            <q-icon name="logout" />
          </q-item-section>
          <q-item-section>
            <q-item-label>Sign Out</q-item-label>
          </q-item-section>
        </q-item>

        <q-item clickable @click="toggleDark">
          <q-item-section avatar>
            <q-icon name="dark_mode" />
          </q-item-section>
          <q-item-section>
            <q-item-label>Toggle Dark Mode</q-item-label>
          </q-item-section>
        </q-item>

      </q-list>
    </q-drawer>

    <q-page-container>
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script>
import { defineComponent, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useQuasar, Dark } from 'quasar'
import { api } from 'src/boot/axios'
import { secureStorage } from 'src/utils/secureStorage'
import EssentialLink from 'components/EssentialLink.vue'

const linksList = [
  {
    title: 'Dashboard',
    caption: 'Map',
    icon: 'public',
    link: '/dashboard'
  },
  {
    title: 'Profile',
    caption: 'Settings & User Data',
    icon: 'record_voice_over',
    link: '/profile'
  }
]

export default defineComponent({
  name: 'MainLayout',

  components: {
    EssentialLink
  },

  setup () {
    const leftDrawerOpen = ref(false)
    const router = useRouter()
    const $q = useQuasar()

    const logout = async () => {
      try {
        await api.delete('/users/sign_out')
        $q.notify({ type: 'positive', message: 'You have been logged out!' })
      } catch (error) {
        console.error('Logout error:', error)
        $q.notify({ type: 'warning', message: 'Logged out locally' })
      }
      await secureStorage.removeToken()
      router.push('/login')
    }

    const toggleDark = () => {
      Dark.toggle()
    }

    return {
      essentialLinks: linksList,
      leftDrawerOpen,
      toggleLeftDrawer () {
        leftDrawerOpen.value = !leftDrawerOpen.value
      },
      logout,
      toggleDark
    }
  }
})
</script>
