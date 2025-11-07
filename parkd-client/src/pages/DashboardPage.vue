<template>
  <q-page class="q-pa-lg flex flex-center">
    <div class="dashboard-wrapper">
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
        <q-card-section>
          <div v-if="road || city" class="q-mb-md">
            <div v-if="road">
              <div class="text-h6">Parked At:</div>
              <div>{{ house_number ? house_number + ' ' : '' }}{{ road }}</div>
              <div v-if="city">{{ city }}</div>
            </div>
          </div>
        </q-card-section>
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
          <q-btn
            label="Draw by Vertex"
            class="q-mt-md"
            color="info"
            @click="$refs.leafletMap.startVertexMode()"
          />
        </q-card-section>

        <q-card-section class="q-pa-none">
          <LeafletMap
            ref="leafletMap"
            :placingParkingSpot="placingParkingSpot"
            :freehand-active="freehandMode"
            :block-select-active="blockSelectActive"
            :vertex-mode-active="vertexMode"
            @shape-drawn="handleDrawnShape"
            @feature-clicked="handleFeatureClick"
            @parking-spot-placed="placingParkingSpot = false"
            @parking-address="populateParkingAddress"
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

    </div>
  </q-page>
</template>

<script>
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
      vertexMode: false,
      blockSelectActive: false,
      freehandMode: false,
      sectionId: null,
      house_number: null,
      road: null,
      city: null
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
    startVertexMode () {
      this.vertexMode = true
      this.freehandMode = false
      this.blockSelectActive = false
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
    populateParkingAddress (addressData) {
      this.house_number = addressData.house_number || null
      this.road = addressData.road || null
      this.city = addressData.city || null
    },
    async handleFeatureClick (feature) {
      const sectionId = feature.properties?.id
      if (!sectionId) return

      try {
        const res = await this.$api.get('/parking_rules', {
          params: { street_section_id: sectionId }
        })
        this.tempRules = res.data

        const props = feature.properties || {}
        this.drawnAddress = props.address || {}
        this.center = props.center || null
        this.bufferedShape = feature
        this.streetDirection = props.street_direction || ''
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
      try {
        if (this.sectionId && rule.id) {
          // Editing an existing rule only
          await this.$api.patch(`/parking_rules/${rule.id}`, { parking_rule: rule })
        } else {
          // Creating a new street section + its first rule
          const payload = {
            coordinates: this.segment,
            address: this.drawnAddress,
            geometry: this.segment?.geometry,
            street_direction: this.streetDirection,
            side_of_street: this.sideOfStreet,
            center: this.center,
            parking_rules_attributes: [rule]
          }
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
