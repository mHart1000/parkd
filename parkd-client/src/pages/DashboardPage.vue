<template>
  <q-page class="q-pa-lg flex flex-center">
    <div class="dashboard-wrapper">
      <div class="text-h5 q-mb-md">Dashboard</div>

      <q-card class="q-pa-md">
        <q-card-section>
          <LeafletMap @shape-drawn="handleDrawnShape" />
        </q-card-section>
        <q-card-section>
          <RulePopup
            v-model="showRulePopup"
            :rules="tempRules"
            @save="handleSaveRules"
          />
        </q-card-section>
      </q-card>
      <q-btn class="q-mt-md" label="Log Out" color="negative" @click="logout" />
    </div>
  </q-page>
</template>

<script>
import { Notify } from 'quasar'
import LeafletMap from 'components/LeafletMap.vue'
import RulePopup from 'components/RulePopup.vue'

export default {
  name: 'DashboardPage',
  components: {
    LeafletMap,
    RulePopup
  },
  data () {
    return {
      lat: 51.505,
      lng: -0.09,
      map: null,
      showRulePopup: false,
      tempRules: [],
      bufferedShape: null,
      drawnAddress: null,
      streetDirection: '',
      sideOfStreet: '',
      geojson: null
    }
  },
  methods: {
    logout () {
      // Clear JWT token from localStorage
      localStorage.removeItem('token')

      // Optionally remove Authorization header from Axios
      this.$api.defaults.headers.common.Authorization = ''

      // Notify user and redirect to login
      Notify.create({ type: 'positive', message: 'You have been logged out!' })
      this.$router.push('/login')
    },
    handleDrawnShape (payload) {
      this.bufferedShape = payload.buffered
      this.drawnAddress = payload.address
      this.center = payload.center
      this.streetDirection = payload.streetDirection
      this.sideOfStreet = payload.sideOfStreet
      this.geojson = payload.geojson
      this.showRulePopup = true
    },

    handleSaveRules (rules) {
      const payload = {
        coordinates: this.bufferedShape,
        address: this.drawnAddress,
        street_direction: this.streetDirection,
        side_of_street: this.sideOfStreet,
        center: this.center,
        parking_rules_attributes: rules
      }

      this.$api.post('/street_sections', { street_section: payload }, {
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`,
          'Content-Type': 'application/json'
        }
      })
        .then(() => {
          this.showRulePopup = false
          this.$q.notify({ type: 'positive', message: 'Rules saved!' })
        })
        .catch(err => {
          console.error('Failed to save:', err)
          this.$q.notify({ type: 'negative', message: 'Error saving rules' })
        })
    }
  }
}
</script>

<style scoped>
</style>
