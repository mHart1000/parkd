<template>
  <q-page class="q-pa-lg flex flex-center">
    <div class="dashboard-wrapper">
      <div class="text-h5 q-mb-md">Dashboard</div>

      <q-banner
        v-if="showParkingConflict"
        class="bg-red text-white q-mb-md"
        rounded
      >
        <div class="text-h5">
          Warning: Upcoming Parking Violation
        </div>
      </q-banner>

      <q-card class="q-pa-md">
        <q-card-section class="row q-gutter-sm">
          <q-btn
            label="Add Parking Spot"
            class="q-mt-md"
            color="primary"
            @click="placingParkingSpot = true"
          />
          <q-btn
            label="Draw Street Section"
            class="q-mt-md"
            color="secondary"
            @click="startFreehand"
          />
          <q-btn
            label="Select Block"
            class="q-mt-md"
            color="accent"
            @click="blockSelectActive = !blockSelectActive"
            :outline="!blockSelectActive"
          />
        </q-card-section>

        <q-card-section class="q-pa-none">
          <LeafletMap
            :placingParkingSpot="placingParkingSpot"
            :freehand-active="freehandMode"
            :block-select-active="blockSelectActive"
            @shape-drawn="handleDrawnShape"
            @feature-clicked="handleFeatureClick"
            @parking-spot-placed="placingParkingSpot = false"
          />
        </q-card-section>
      </q-card>

      <RulePopup
        v-model="showRulePopup"
        :rules="tempRules"
        :street-name="drawnAddress?.road || ''"
        :city="drawnAddress?.city || ''"
        :street-direction="streetDirection"
        :address="drawnAddress?.house_number ? `${drawnAddress.house_number} ${drawnAddress.road || drawnAddress.street || ''}` : ''"
        @save="handleSaveRules"
      />

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
      blockSelectActive: false,
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
    startFreehand () {
      this.freehandMode = true
    },
    handleDrawnShape (payload) {
      console.log('handleDrawnShape payload:', payload)
      this.bufferedShape = payload.buffered
      this.segment = payload.segment
      this.drawnAddress = payload.address
      this.center = payload.center
      this.streetDirection = payload.streetDirection
      this.sideOfStreet = payload.sideOfStreet
      this.geojson = payload.geojson
      this.sectionId = null
      this.showRulePopup = true
      this.freehandMode = false
    },
    async handleFeatureClick (feature) {
      console.log('handleFeatureClick feature:', feature)
      const sectionId = feature.properties?.id
      if (!sectionId) return

      try {
        const res = await this.$api.get('/parking_rules', {
          params: { street_section_id: sectionId }
        })
        console.log('handleFeatureClick Fetched res:', res)
        console.log('handleFeatureClick Fetched res data:', res.data)
        this.tempRules = res.data

        const props = feature.properties.address || {}
        const road = props.road
        const houseNumber = props.house_number
        const city = props.city
        this.drawnAddress = {
          road,
          houseNumber,
          city
        }
        console.log('handleFeatureClick drawnAddress:', this.drawnAddress)
        this.center = props.center || null
        this.bufferedShape = feature
        this.streetDirection = props.street_direction || props.direction || ''
        this.sideOfStreet = props.side_of_street || ''
        this.geojson = feature
        this.sectionId = sectionId
        this.showRulePopup = true
      } catch (err) {
        console.error('[handleFeatureClick] Failed to load rules:', err)
        this.$q.notify({ type: 'negative', message: 'Could not load rules for section' })
      }
    },
    async handleSaveRules (rule) {
      const payload = {
        coordinates: this.segment,
        address: this.drawnAddress,
        geometry: this.segment.geometry, // LineString
        street_direction: this.streetDirection,
        side_of_street: this.sideOfStreet,
        center: this.center,
        parking_rules_attributes: [rule]
      }

      try {
        if (this.sectionId) {
          await this.$api.patch(`/street_sections/${this.sectionId}`, { street_section: payload })
        } else {
          await this.$api.post('/street_sections', { street_section: payload })
        }

        this.showRulePopup = false
        this.blockSelectActive = false
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
