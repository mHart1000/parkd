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
import { createFreehandLine } from '../utils/freehandLine.js'

export default {
  name: 'LeafletMap',
  data () {
    return {
      map: null,
      lat: 51.505,
      lng: -0.09,
      freehand: null,
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
    }
  },
  mounted () {
    this.initMap()
    this.getLocation()
    this.populateMap()
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
        onFinish: this.handleFreehandFinish
      })

      this.map.on('pm:create', async (e) => {
        const layer = e.layer
        const geojson = layer.toGeoJSON()
        console.log('universal geojson', geojson)

        // gets centerline of actual street at location
        const lineCenter = turf.center(geojson)
        const [lng, lat] = lineCenter.geometry.coordinates
        // gets street/location
        const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}`, {
          headers: { 'User-Agent': 'parkd-app-dev (mhart4040@gmail.com)' }
        })
        const data = await res.json()
        const street = data.address?.road
        const streetLine = await this.fetchStreetGeometry(street, lat, lng)
        const bearing = this.getBearing(streetLine)

        console.log('center', lineCenter)
        console.log('Center coordinates:', lng, lat)
        console.log('Drawn shape:', geojson)
        console.log('Street address:', data.address)
        console.log('Street name:', street)

        if (geojson.geometry.type === 'Point') {
          const side = this.sideOfStreetFinder(geojson, streetLine, lat, lng, bearing)
          this.saveParkingSpot(geojson, data, side, layer)
          return
        }

        // For non-point geometry, try to snap freehand to street and buffer
        const snapped = this.snapFreehandToStreetSegment(geojson, streetLine)

        // Prepare variables used in emitted payload
        let buffered = null
        let segment = null
        let centerForProps = [lng, lat]
        let sideOfStreet = null

        if (snapped) {
          // replace drawn line with street-aligned buffered polygon
          layer.remove()
          L.geoJSON(snapped.buffered, {
            style: { color: '#4A90E2', fillColor: '#4A90E2', fillOpacity: 0.4 }
          }).addTo(this.map)

          // recompute center for better accuracy (use the snapped segment)
          const snappedCenter = turf.center(snapped.segment)
          centerForProps = snappedCenter.geometry.coordinates

          // determine side of street from the snapped center
          sideOfStreet = this.sideOfStreetFinder(
            turf.point(centerForProps),
            streetLine,
            centerForProps[1],
            centerForProps[0],
            bearing
          )

          buffered = snapped.buffered
          segment = snapped.segment
        } else {
          // fallback to buffering the original drawn geometry
          buffered = this.drawBufferedShape(geojson, layer)
          sideOfStreet = this.sideOfStreetFinder(geojson, streetLine, lat, lng, bearing)
        }

        this.$emit('shape-drawn', {
          buffered,
          segment,
          address: data.address,
          streetName: street,
          streetDirection: this.cardinalDirection(bearing),
          center: centerForProps,
          sideOfStreet,
          geojson: buffered // downstream expects a polygon feature; keep it handy
        })
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
    snapFreehandToStreetSegment (freehandLine, streetLine) {
      const coords = turf.getCoords(freehandLine)
      if (!coords || coords.length < 2) return null

      const start = turf.point(coords[0])
      const end = turf.point(coords[coords.length - 1])

      const nStart = turf.nearestPointOnLine(streetLine, start)
      const nEnd = turf.nearestPointOnLine(streetLine, end)

      // slice the street centerline between projected start/end
      const segment = turf.lineSlice(nStart, nEnd, streetLine)

      // safety: if the slice failed or degenerate, fall back
      const segCoords = turf.getCoords(segment)
      if (!segCoords || segCoords.length < 2) return null

      // buffer to create the “fat line” polygon you already expect/sync to backend
      const buffered = turf.buffer(segment, 1.8, { units: 'meters' })

      return { segment, buffered }
    },
    async handleFreehandFinish (geojson, layer) {
      try {
        // center for reverse geocoding
        const lineCenter = turf.center(geojson)
        const [lng, lat] = lineCenter.geometry.coordinates

        const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}`, {
          headers: { 'User-Agent': 'parkd-app-dev (mhart4040@gmail.com)' }
        })
        const data = await res.json()
        const street = data.address?.road
        const streetLine = await this.fetchStreetGeometry(street, lat, lng)
        const bearing = this.getBearing(streetLine)

        // NEW: snap to street, buffer the snapped segment
        const snapped = this.snapFreehandToStreetSegment(geojson, streetLine)

        // draw the result and compute side of street from snapped geometry when available
        let buffered
        let sideOfStreet
        let centerForProps = [lng, lat]

        if (snapped) {
          // replace drawn line with street-aligned buffered polygon
          layer.remove()
          L.geoJSON(snapped.buffered, {
            style: { color: '#4A90E2', fillColor: '#4A90E2', fillOpacity: 0.4 }
          }).addTo(this.map)

          // recompute center for better accuracy (use the snapped segment)
          const snappedCenter = turf.center(snapped.segment)
          centerForProps = snappedCenter.geometry.coordinates

          // determine side of street from the snapped center
          sideOfStreet = this.sideOfStreetFinder(
            turf.point(centerForProps),
            streetLine,
            centerForProps[1],
            centerForProps[0],
            bearing
          )

          buffered = snapped.buffered
        } else {
          // fallback to your previous behavior if snapping fails
          const tmpSide = this.sideOfStreetFinder(geojson, streetLine, lat, lng, bearing)
          sideOfStreet = tmpSide
          buffered = this.drawBufferedShape(geojson, layer)
        }

        this.$emit('shape-drawn', {
          buffered,
          address: data.address,
          streetName: street,
          streetDirection: this.cardinalDirection(bearing),
          center: centerForProps,
          sideOfStreet,
          geojson: buffered // downstream expects a polygon feature; keep it handy
        })
      } catch (err) {
        console.error('[handleFreehandFinish] error:', err)
        this.$q.notify({ type: 'negative', message: 'Failed to process freehand line' })
      }
    },
    sideOfStreetFinder (geojson, streetLine, lat, lng, bearing) {
      try {
        const nearest = turf.nearestPointOnLine(streetLine, geojson)
        const [streetLng, streetLat] = nearest.geometry.coordinates

        if (bearing <= 20 || bearing >= 160) {
          return lng < streetLng ? 'west side' : 'east side'
        } else if (bearing >= 70 && bearing <= 110) {
          return lat < streetLat ? 'south side' : 'north side'
        } else {
          return 'diagonal'
        }
      } catch (e) {
        console.warn('Street geometry fetch failed:', e.message)
        return null
      }
    },
    getBearing (streetLine) {
      const tmpBearing = turf.bearing(
        turf.point(streetLine.geometry.coordinates[0]),
        turf.point(streetLine.geometry.coordinates.at(-1))
      )
      return Math.abs(tmpBearing)
    },
    cardinalDirection (abs) {
      if (abs <= 20 || abs >= 160) return 'north-south'
      if (abs >= 70 && abs <= 110) return 'east-west'
      return 'diagonal'
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

        L.geoJSON(geojson, {
          pointToLayer: (geoJsonPoint, latlng) => {
            return L.marker(latlng, { icon: this.carIcon })
          }
        }).addTo(this.map)
      } catch (err) {
        console.error('[Save Parking Spot] error:', err)
        this.$q.notify({ type: 'negative', message: 'Failed to save parking spot' })
      }

      layer.remove() // Remove temporary marker
      this.$emit('parking-spot-placed')
    },
    drawBufferedShape (geojson, layer) {
      // constructs fat line
      const coords = turf.getCoords(geojson)
      const lineFeature = turf.lineString(coords)
      const buffered = turf.buffer(lineFeature, 1.8, { units: 'meters' })

      console.log('Line feature:', lineFeature)
      console.log('Coordinates:', coords)
      console.log('Buffered polygon:', buffered)

      // defers removing the line layer to avoid race condition
      layer.remove()
      // draws fat line
      L.geoJSON(buffered, {
        style: {
          color: '#4A90E2',
          fillColor: '#4A90E2',
          fillOpacity: 0.4
        }
      }).addTo(this.map)
      return buffered
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

          const [lng, lat] = spot.coordinates.geometry.coordinates
          console.log('lat', lat)
          console.log('lng', lng)
          console.log('spot', spot)
          console.log('spot.coordinates', spot.coordinates)
          const marker = L.marker([lat, lng], { icon: this.carIcon })

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
