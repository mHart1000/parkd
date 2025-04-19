<template>
  <div id="map" style="width: 500px; height: 400px;"></div>
</template>

<script>
import L from 'leaflet'
import { Geolocation } from '@capacitor/geolocation'
import '@geoman-io/leaflet-geoman-free'
import '@geoman-io/leaflet-geoman-free/dist/leaflet-geoman.css'
import 'leaflet/dist/leaflet.css'

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
      this.map = L.map('map').setView([this.lat, this.lng], 17)

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

      this.map.on('pm:create', (e) => {
        const layer = e.layer
        const geojson = layer.toGeoJSON()
        console.log('Drawn shape:', geojson)

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
