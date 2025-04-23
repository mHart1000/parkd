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

export default {
  name: 'LeafletMap',
  data () {
    return {
      map: null,
      lat: 51.505,
      lng: -0.09
    }
  },
  props: {
    placingParkingSpot: {
      type: Boolean,
      default: false
    }
  },
  mounted () {
    this.initMap()
    this.getLocation()
    this.populateMap()
  },
  watch: {
    placingParkingSpot (val) {
      if (val) {
        this.map.pm.enableDraw('Marker')
        this.$q.notify({ type: 'info', message: 'Click on the map to place a parking spot' })
      } else {
        this.map.pm.disableDraw('Marker')
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
        drawPolyline: true,
        drawRectangle: false,
        drawCircle: false,
        drawMarker: true,
        drawCircleMarker: false,
        editMode: true,
        dragMode: true,
        removalMode: true
      })

      this.map.on('pm:create', async (e) => {
        const layer = e.layer
        const geojson = layer.toGeoJSON()

        if (geojson.geometry.type === 'Point') {
          const [lng, lat] = geojson.geometry.coordinates

          const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}`, {
            headers: { 'User-Agent': 'parkd-app-dev (mhart4040@gmail.com)' }
          })
          const data = await res.json()
          const street = data.address?.road

          let sideOfStreet
          try {
            const streetLine = await this.fetchStreetGeometry(street, lat, lng)
            const nearest = turf.nearestPointOnLine(streetLine, geojson)
            const [streetLng, streetLat] = nearest.geometry.coordinates

            const bearing = turf.bearing(
              turf.point(streetLine.geometry.coordinates[0]),
              turf.point(streetLine.geometry.coordinates.at(-1))
            )
            const abs = Math.abs(bearing)

            if (abs <= 20 || abs >= 160) {
              sideOfStreet = lng < streetLng ? 'west side' : 'east side'
            } else if (abs >= 70 && abs <= 110) {
              sideOfStreet = lat < streetLat ? 'south side' : 'north side'
            } else {
              sideOfStreet = 'diagonal'
            }
          } catch (e) {
            console.warn('Street geometry fetch failed:', e.message)
          }

          try {
            await this.$api.post('/parking_spots', {
              parking_spot: {
                coordinates: { lat, lng },
                address: data.address,
                side_of_street: sideOfStreet,
                active: true
              }
            })

            this.$q.notify({ type: 'positive', message: 'Parking spot saved!' })

            L.geoJSON(geojson, {
              pointToLayer: (geoJsonPoint, latlng) => {
                return L.marker(latlng, { icon: L.icon({ iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png' }) })
              }
            }).addTo(this.map)
          } catch (err) {
            console.error('[Save Parking Spot] error:', err)
            this.$q.notify({ type: 'negative', message: 'Failed to save parking spot' })
          }

          layer.remove() // Remove temporary marker
          this.$emit('parking-spot-placed')
        } else {
          // gets street/location
          const lineCenter = turf.center(geojson)
          const [lineCenterLng, lineCenterLat] = lineCenter.geometry.coordinates
          const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lineCenterLat}&lon=${lineCenterLng}`, {
            headers: { 'User-Agent': 'parkd-app-dev (mhart4040@gmail.com)' }
          })
          const data = await res.json()
          const street = data.address?.road

          // gets centerline of actual street at location
          let sideOfStreet
          try {
            const streetLine = await this.fetchStreetGeometry(street, lineCenterLat, lineCenterLng)
            console.log('Street centerline:', streetLine)

            const nearest = turf.nearestPointOnLine(streetLine, lineCenter)
            console.log('Nearest point on line:', nearest)
            const [streetCenterLng, streetCenterLat] = nearest.geometry.coordinates

            // get direction of street
            const lineCoords = turf.getCoords(streetLine)
            const centerlineStart = turf.point(lineCoords[0])
            const centerlineEnd = turf.point(lineCoords[lineCoords.length - 1])
            const centerlineBearing = turf.bearing(centerlineStart, centerlineEnd)
            const absBearing = Math.abs(centerlineBearing)

            if (absBearing <= 20 || absBearing >= 160) {
              sideOfStreet = lineCenterLng < streetCenterLng ? 'west side' : 'east side'
            } else if (absBearing >= 70 && absBearing <= 110) {
              sideOfStreet = lineCenterLat < streetCenterLat ? 'south side' : 'north side'
            } else {
              sideOfStreet = 'diagonal'
            }

            console.log('Street direction (bearing):', centerlineBearing.toFixed(2))
            console.log('Determined side of street:', sideOfStreet)
          } catch (e) {
            console.warn('Street geometry fetch failed:', e.message)
          }

          console.log('center', lineCenter)
          console.log('Center coordinates:', lineCenterLng, lineCenterLat)
          console.log('Drawn shape:', geojson)
          console.log('Street address:', data.address)
          console.log('Street name:', street)

          // makes phat line
          const coords = turf.getCoords(geojson)
          const lineFeature = turf.lineString(coords)
          const buffered = turf.buffer(lineFeature, 1.8, { units: 'meters' })

          console.log('Line feature:', lineFeature)
          console.log('Coordinates:', coords)
          console.log('Buffered polygon:', buffered)

          // defers removing the line layer to avoid race condition
          layer.remove()
          // draws the phat line
          L.geoJSON(buffered, {
            style: {
              color: '#4A90E2',
              fillColor: '#4A90E2',
              fillOpacity: 0.4
            }
          }).addTo(this.map)

          const lineStart = turf.point(coords[0])
          const lineEnd = turf.point(coords[coords.length - 1])

          const bearing = turf.bearing(lineStart, lineEnd)

          console.log('bearing', bearing)

          function cardinalDirection (bearing) {
            const abs = Math.abs(bearing)
            if (abs <= 20 || abs >= 160) return 'north-south'
            if (abs >= 70 && abs <= 110) return 'east-west'
            return 'diagonal'
          }

          console.log('Street direction:', cardinalDirection(bearing))

          // Store it
          localStorage.setItem('lastDrawnBuffer', JSON.stringify(buffered))
          localStorage.setItem('lastDrawnShape', JSON.stringify(geojson))
          this.$emit('shape-drawn', {
            buffered,
            address: data.address,
            streetName: street,
            streetDirection: cardinalDirection(bearing),
            center: [lineCenterLng, lineCenterLat],
            sideOfStreet,
            geojson
          })
        }
      })

      // Restore last shape
      const saved = localStorage.getItem('lastDrawnShape')
      if (saved) {
        const layer = L.geoJSON(JSON.parse(saved))
        layer.addTo(this.map)
        this.map.fitBounds(layer.getBounds())
      }
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
    async fetchStreetGeometry (streetName, lat, lng) {
      const overpassUrl = 'https://overpass-api.de/api/interpreter'

      const query = `
        [out:json][timeout:25];
        (
          way["highway"]["name"="${streetName}"](around:50,${lat},${lng});
        );
        out geom;
      `

      const response = await fetch(overpassUrl, {
        method: 'POST',
        body: query
      })

      const data = await response.json()

      if (!data.elements || data.elements.length === 0) {
        throw new Error(`No geometry found for "${streetName}"`)
      }

      // Convert first match to GeoJSON LineString
      const way = data.elements.find(el => el.type === 'way')
      const coordinates = way.geometry.map(pt => [pt.lon, pt.lat])

      return {
        type: 'Feature',
        geometry: {
          type: 'LineString',
          coordinates
        },
        properties: {
          id: way.id,
          name: streetName
        }
      }
    },
    populateMap () {
      this.$api.get('/street_sections')
        .then(res => {
          console.log('res', res)
          console.log('res.data', res.data)
          const featureCollection = res.data
          L.geoJSON(featureCollection, {
            onEachFeature: (feature, layer) => {
              layer.on('click', () => {
                if (this.placingParkingSpot) return
                this.$emit('feature-clicked', feature)
              })
            }
          }).addTo(this.map)
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

          const { lat, lng } = spot.coordinates

          const marker = L.marker([lat, lng], {
            icon: L.icon({
              iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png'
            })
          })

          marker.bindPopup('Your active parking spot')
          marker.addTo(this.map)
        })
        .catch(err => {
          console.error('[populateMap] Failed to load parking spot:', err)
        })
    }
  }
}
</script>
