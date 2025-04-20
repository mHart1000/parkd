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
  mounted () {
    this.initMap()
    this.getLocation()
  },
  methods: {
    initMap () {
      this.map = markRaw(L.map('map').setView([this.lat, this.lng], 17))

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
      }).addTo(this.map)

      this.map.pm.addControls({
        position: 'topright',
        drawPolygon: true,
        drawPolyline: true,
        drawRectangle: false,
        drawCircle: false,
        drawMarker: false,
        drawCircleMarker: false,
        editMode: true,
        dragMode: true,
        removalMode: true
      })

      this.map.on('pm:create', async (e) => {
        const layer = e.layer
        const geojson = layer.toGeoJSON()

        // gets street/location
        const center = turf.center(geojson)
        const [cntrLng, cntrLat] = center.geometry.coordinates
        const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${cntrLat}&lon=${cntrLng}`, {
          headers: { 'User-Agent': 'parkd-app-dev (mhart4040@gmail.com)' }
        })
        const data = await res.json()
        const street = data.address?.road

        console.log('ceneter', center)
        console.log('Center coordinates:', cntrLng, cntrLat)
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

        // differs removing the line layer to avoid race condition
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
        this.map.setView([this.lat, this.lng], 13)
        L.marker([this.lat, this.lng]).addTo(this.map)
        localStorage.setItem('location', JSON.stringify({
          latitude: this.lat,
          longitude: this.lng
        }))
      } catch (error) {
        console.error('Error getting location:', error)
      }
    }
  }
}
</script>
