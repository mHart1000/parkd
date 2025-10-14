<template>
  <div id="map" style="width: 500px; height: 400px;"></div>
</template>

<script>
import L from 'leaflet'
import { Geolocation } from '@capacitor/geolocation'
import '@geoman-io/leaflet-geoman-free'
import '@geoman-io/leaflet-geoman-free/dist/leaflet-geoman.css'
import 'leaflet/dist/leaflet.css'
import * as turf from '@turf/turf'
import { markRaw } from 'vue'
import { createFreehandLine } from '../utils/freehandLineDraw.js'
import { handleBlockClick } from '../utils/blockSelect.js'
import { handleFreehandFinish, drawBufferedShape } from '../utils/freehandProcessing.js'

const CLIENT_USER_AGENT = import.meta.env.VITE_CLIENT_USER_AGENT

export default {
  name: 'LeafletMap',
  emits: [
    'shape-drawn',
    'feature-clicked',
    'parking-spot-placed',
    'parking-address'
  ],
  data () {
    return {
      map: null,
      lat: 32.73,
      lng: -117.16,
      freehand: null,
      overpassUrl: 'https://overpass-api.de/api/interpreter',
      candidateLayers: [],
      currentParkingSpot: null,
      carIcon: L.divIcon({
        html: '<i class="fa-solid fa-car-side" style="font-size:24px;color:#0fe004"></i>',
        className: '',
        iconSize: [24, 24],
        iconAnchor: [12, 24]
      })
    }
  },
  props: {
    placingParkingSpot: {
      type: Boolean,
      default: false
    },
    freehandActive: {
      type: Boolean,
      default: false
    },
    blockSelectActive: {
      type: Boolean,
      default: false
    }
  },
  mounted () {
    this.initMap()
    this.getLocation()
    this.populateMap()
    this._blockClickHandler = async e => {
      this.candidateLayers = await handleBlockClick(
        e,
        this.overpassUrl,
        this.candidateLayers,
        this.$q,
        this.map,
        this.$emit,
        updated => { this.candidateLayers = updated }
      )
    }
    window.turf = turf // testing only
  },
  watch: {
    placingParkingSpot (val) {
      if (val) {
        this.map.pm.enableDraw('Marker', {
          markerStyle: {
            icon: this.carIcon
          }
        })
        this.$q.notify({ type: 'info', message: 'Click on the map to place a parking spot' })
      } else {
        this.map.pm.disableDraw('Marker')
      }
    },
    freehandActive (val) {
      if (!this.freehand) return
      if (val) {
        this.freehand.enable()
        this.$q.notify({ type: 'info', message: 'Freehand mode: drag to draw, release to finish' })
      } else {
        this.freehand.disable()
      }
    },
    blockSelectActive (val) {
      if (val) {
        this.$q.notify({ type: 'info', message: 'Block-select mode: click a street to highlight blocks' })
        this.map.on('click', this._blockClickHandler)
      } else {
        this.map.off('click', this._blockClickHandler)
      }
    }
  },
  methods: {
    initMap () {
      this.map = markRaw(L.map('map').setView([this.lat, this.lng], 17))

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
      }).addTo(this.map)

      this.map.pm.addControls({
        position: 'topright',
        drawPolygon: false,
        drawPolyline: false,
        drawRectangle: false,
        drawCircle: false,
        drawMarker: true,
        drawCircleMarker: false,
        drawFreehand: true,
        editMode: true,
        dragMode: true,
        removalMode: true
      })

      this.freehand = createFreehandLine(this.map, {
        onFinish: (geojson, layer) => handleFreehandFinish(geojson, layer, this.map, this.$emit, this.$q, this.overpassUrl)
      })

      this.map.on('pm:create', async (e) => {
        const layer = e.layer
        const geojson = layer.toGeoJSON()

        if (!geojson?.geometry || geojson.geometry.type !== 'Point') {
          // For non-points use handleFreehandFinish
          this.safeRemoveLayer(layer)
          return
        }

        // For markers: reverse-geocode and save the parking spot.
        try {
          const lineCenter = turf.center(geojson)
          const [lng, lat] = lineCenter.geometry.coordinates
          const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}`, {
            headers: { 'User-Agent': CLIENT_USER_AGENT }
          })
          const data = await res.json()
          const street = data.address?.road

          let side = null
          try {
            const streetLine = await this.fetchStreetGeometry(street, lat, lng)
            const bearing = this.getBearing(streetLine)
            side = this.sideOfStreetFinder(geojson, streetLine, lat, lng, bearing)
          } catch (err) {
            side = null
          }

          this.saveParkingSpot(geojson, data, side, layer)
        } catch (err) {
          console.error('[pm:create] failed to process marker:', err)
          this.safeRemoveLayer(layer)
        }
      })
    },
    async getLocation () {
      try {
        const coordinates = await Geolocation.getCurrentPosition()
        this.lat = coordinates.coords.latitude
        this.lng = coordinates.coords.longitude
        this.map.setView([this.lat, this.lng], 17)
        L.marker([this.lat, this.lng]).addTo(this.map)
        localStorage.setItem('location', JSON.stringify({
          latitude: this.lat,
          longitude: this.lng
        }))
      } catch (error) {
        console.error('Error getting location:', error)
      }
    },
    async saveParkingSpot (geojson, data, sideOfStreet, layer) {
      try {
        await this.$api.post('/parking_spots', {
          parking_spot: {
            coordinates: geojson,
            geometry: geojson.geometry,
            address: data.address,
            side_of_street: sideOfStreet,
            active: true
          }
        })

        this.$q.notify({ type: 'positive', message: 'Parking spot saved!' })

        const marker = L.geoJSON(geojson, {
          pointToLayer: (geoJsonPoint, latlng) => {
            return L.marker(latlng, { icon: this.carIcon })
          }
        })
        this.safeRemoveLayer(this.currentParkingSpot)
        this.currentParkingSpot = marker
        marker.addTo(this.map)
      } catch (err) {
        console.error('[Save Parking Spot] error:', err)
        this.$q.notify({ type: 'negative', message: 'Failed to save parking spot' })
      }

      layer.remove() // Remove temporary marker
      this.$emit('parking-address', data.address)
      this.$emit('parking-spot-placed')
    },
    safeRemoveLayer (layer) {
      if (!layer || typeof layer.remove !== 'function') return false
      // Check whether the map contains the layer before removal to avoid race conditions with drawing library
      try {
        if (this.map && typeof this.map.hasLayer === 'function' && !this.map.hasLayer(layer)) {
          return false
        }

        layer.remove()
        return true
      } catch (err) {
        // Only emit debug logs in non-production
        if (typeof process !== 'undefined' && process.env && process.env.NODE_ENV !== 'production') {
          console.debug('[LeafletMap] safeRemoveLayer failed:', err)
        }
        // TODO: When preparing for deploy, enable Sentry
        return false
      }
    },
    populateMap () {
      this.$api.get('/street_sections')
        .then(res => {
          console.log('res', res)
          console.log('res.data', res.data)
          const featureCollection = res.data
          L.geoJSON(featureCollection, {
            onEachFeature: (feature) => {
              drawBufferedShape(feature.geometry, null, this.map)

              this.map.on('click', (e) => {
                if (this.placingParkingSpot) return
                this.$emit('feature-clicked', feature)
              })
            }
          })
        })
        .catch(err => {
          console.error('[populateMap] Failed to load street sections:', err)
        })
      this.$api.get('/parking_spots', {
        params: { active: true }
      })
        .then(res => {
          const spot = res.data
          if (!spot || !spot.coordinates) return

          const [lng, lat] = spot.coordinates.geometry.coordinates
          console.log('lat', lat)
          console.log('lng', lng)
          console.log('spot', spot)
          console.log('spot.coordinates', spot.coordinates)
          this.addressData = { house_number: spot.address.house_number, road: spot.address.road, city: spot.address.city }
          this.$emit('parking-address', this.addressData)
          const marker = L.marker([lat, lng], { icon: this.carIcon })
          marker.bindPopup('Your active parking spot')
          marker.addTo(this.map)
          this.currentParkingSpot = marker
        })
        .catch(err => {
          console.error('[populateMap] Failed to load parking spot:', err)
        })
    }
  }
}
</script>
