<template>
  <q-page class="q-pa-lg flex flex-center">
    <div class="dashboard-wrapper">
      <div class="text-h5 q-mb-md">Dashboard</div>
      <q-banner
        v-if="showParkingConflict"
        class="bg-red text-white q-mb-md q-pa-lg "
        rounded
      >
        <div class="text-h5">
          Warning: Upcoming Parking Violation
        </div>
      </q-banner>
      <q-card class="q-pa-md">
        <q-card-section>
          <q-btn
            label="Add Parking Spot"
            class="q-mt-md"
            color="primary"
            @click="placingParkingSpot = true"
          />
          <q-btn
            :label="freehandMode ? 'Finish Freehand' : 'Draw Street Section'"
            class="q-mt-md"
            color="secondary"
            @click="freehandMode = !freehandMode"
            :outline="!freehandMode"
          />
        </q-card-section>
        <q-card-section>
          <LeafletMap
            :placingParkingSpot="placingParkingSpot"
            :freehand-active="freehandMode"
            @shape-drawn="handleDrawnShape"
            @feature-clicked="handleFeatureClick"
            @parking-spot-placed="placingParkingSpot = false"
          />
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
      segment: null,
      drawnAddress: null,
      streetDirection: '',
      sideOfStreet: '',
      geojson: null,
      placingParkingSpot: false,
      showParkingConflict: false,
      freehandMode: false,
      sectionId: null
    }
  },
  async mounted () {
    try {
      const res = await this.$api.get('/alerts/nearby_upcoming_rules')
      this.showParkingConflict = res.data.alert
    } catch (err) {
      console.error('[Dashboard] Warning check failed:', err)
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
      this.segment = payload.segment
      this.drawnAddress = payload.address
      this.center = payload.center
      this.streetDirection = payload.streetDirection
      this.sideOfStreet = payload.sideOfStreet
      this.geojson = payload.geojson
      this.sectionId = null
      this.showRulePopup = true
    },
    async handleFeatureClick (feature) {
      const sectionId = feature.properties?.id
      if (!sectionId) return

      try {
        const res = await this.$api.get('/parking_rules', {
          params: { street_section_id: sectionId }
        })
        console.log('handleFeatureClick Fetched res:', res)
        console.log('handleFeatureClick Fetched res data:', res.data)
        this.tempRules = res.data
        this.drawnAddress = feature.properties?.address || {}
        this.center = feature.properties?.center || null
        this.bufferedShape = feature
        this.streetDirection = feature.properties?.street_direction || ''
        this.sideOfStreet = feature.properties?.side_of_street || ''
        this.geojson = feature
        this.sectionId = sectionId
        this.showRulePopup = true
      } catch (err) {
        console.error('[handleFeatureClick] Failed to load rules:', err)
        this.$q.notify({ type: 'negative', message: 'Could not load rules for section' })
      }
    },
    async handleSaveRules (rules) {
      const payload = {
        coordinates: this.segment,
        address: this.drawnAddress,
        geometry: this.segment.geometry, // LineString
        street_direction: this.streetDirection,
        side_of_street: this.sideOfStreet,
        center: this.center,
        parking_rules_attributes: rules
      }

      try {
        if (this.sectionId) {
          await this.$api.patch(`/street_sections/${this.sectionId}`, { street_section: payload })
        } else {
          await this.$api.post('/street_sections', { street_section: payload })
        }

        this.showRulePopup = false
        this.$q.notify({ type: 'positive', message: 'Rules saved!' })
      } catch (err) {
        console.error('[handleSaveRules] Error saving:', err)
        this.$q.notify({ type: 'negative', message: 'Error saving rules' })
      }
    }
  }
}
</script>

<style scoped>
</style>
