import * as turf from '@turf/turf'
import L from 'leaflet'

export async function handleFreehandFinish (geojson, layer, map, $emit, $q, overpassUrl, skipSnapping = false) {
  try {
    // center for reverse geocoding
    const lineCenter = turf.center(geojson)
    const [lng, lat] = lineCenter.geometry.coordinates

    const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}`, {
      headers: { 'User-Agent': import.meta.env.VITE_CLIENT_USER_AGENT }
    })
    const data = await res.json()
    const street = data.address?.road

    let buffered
    let sideOfStreet = null
    let centerForProps = [lng, lat]
    let streetDirection = null

    if (skipSnapping) {
      // Vertex mode: do not use Overpass or snapping, draw exactly what the user clicked
      buffered = drawBufferedShape(geojson, layer, map)
      streetDirection = 'unsnapped'
    } else {
      // Freehand / block-select: align with street data
      const streetLine = await fetchStreetGeometry(street, lat, lng, overpassUrl)
      const bearing = getBearing(streetLine)
      streetDirection = cardinalDirection(bearing)

      const snapped = snapFreehandToStreetSegment(geojson, streetLine)

      if (snapped) {
        layer.remove()
        L.geoJSON(snapped.buffered, {
          style: { color: '#4A90E2', fillColor: '#4A90E2', fillOpacity: 0.4 }
        }).addTo(map)

        const snappedCenter = turf.center(snapped.segment)
        centerForProps = snappedCenter.geometry.coordinates
        sideOfStreet = sideOfStreetFinder(
          turf.point(centerForProps),
          streetLine,
          centerForProps[1],
          centerForProps[0],
          bearing
        )
        buffered = snapped.buffered
      } else {
        buffered = drawBufferedShape(geojson, layer, map)
      }
    }

    // Always ensure we have a LineString to send
    const safeSegment = turf.lineString(turf.getCoords(geojson))

    $emit('shape-drawn', {
      buffered, // polygon for display
      segment: safeSegment, // always a LineString
      address: data.address,
      streetName: street,
      streetDirection,
      center: centerForProps,
      sideOfStreet,
      geojson: safeSegment // send LineString to API
    })
  } catch (err) {
    console.error('[handleFreehandFinish] error:', err)
    $q.notify({ type: 'negative', message: 'Failed to process line' })
  }
}

export async function fetchStreetGeometry (streetName, lat, lng, overpassUrl = 'https://overpass-api.de/api/interpreter') {
  const query = `
        [out:json][timeout:25];
        way(around:5,${lat},${lng})["highway"];
        (._;>;);
        out geom;
      `

  const response = await fetch(overpassUrl, { method: 'POST', body: query })
  const data = await response.json()
  console.log('Overpass data:', data)
  if (!data.elements || data.elements.length === 0) {
    throw new Error(`No geometry found for "${streetName}"`)
  }

  // Pick the nearest single block
  const nearestWay = data.elements
    .filter(el => el.type === 'way' && el.geometry)
    .map(el => {
      const line = turf.lineString(el.geometry.map(pt => [pt.lon, pt.lat]))
      const clickPoint = turf.point([lng, lat])
      return { el, dist: turf.pointToLineDistance(clickPoint, line) }
    })
    .sort((a, b) => a.dist - b.dist)[0]?.el

  if (!nearestWay) throw new Error(`No valid block found for "${streetName}"`)

  const coordinates = nearestWay.geometry.map(pt => [pt.lon, pt.lat])

  return {
    type: 'Feature',
    geometry: { type: 'LineString', coordinates },
    properties: { id: nearestWay.id, name: streetName }
  }
}
export function snapFreehandToStreetSegment (freehandLine, streetLine) {
  console.log('Freehand line:', freehandLine)
  console.log('Street line:', streetLine)
  console.log('Freehand coords:', turf.getCoords(freehandLine))
  const coords = turf.getCoords(freehandLine)
  if (!coords || coords.length < 2) return null

  const freehandStart = turf.point(coords[0])
  const freehandEnd = turf.point(coords[coords.length - 1])

  console.log('Start point:', freehandStart)
  console.log('End point:', freehandEnd)

  const streetStart = turf.nearestPointOnLine(streetLine, freehandStart)
  const streetEnd = turf.nearestPointOnLine(streetLine, freehandEnd)

  console.log('Nearest start:', streetStart)
  console.log('Nearest end:', streetEnd)

  // slice the street centerline between projected start/end
  const segment = turf.lineSlice(streetStart, streetEnd, streetLine)

  console.log('Sliced segment:', segment)

  // safety: if the slice failed or degenerate, fall back
  const segCoords = turf.getCoords(segment)
  if (!segCoords || segCoords.length < 2) return null

  // buffer to create the fat line
  const buffered = turf.buffer(segment, 1.8, { units: 'meters' })

  return { segment, buffered }
}
export function sideOfStreetFinder (geojsonCoords, streetLine, lat, lng, bearing) {
  try {
    const nearest = turf.nearestPointOnLine(streetLine, geojsonCoords)
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
}
export function getBearing (streetLine) {
  const tmpBearing = turf.bearing(
    turf.point(streetLine.geometry.coordinates[0]),
    turf.point(streetLine.geometry.coordinates.at(-1))
  )
  return Math.abs(tmpBearing)
}
export function cardinalDirection (abs) {
  if (abs <= 20 || abs >= 160) return 'north-south'
  if (abs >= 70 && abs <= 110) return 'east-west'
  return 'diagonal'
}
export function drawBufferedShape (geojson, layer, map) {
  const coords = turf.getCoords(geojson)
  const lineFeature = turf.lineString(coords)
  const buffered = turf.buffer(lineFeature, 1.8, { units: 'meters' })

  console.log('Line feature:', lineFeature)
  console.log('Coordinates:', coords)
  console.log('Buffered polygon:', buffered)

  if (layer && typeof layer.remove === 'function') layer.remove()

  L.geoJSON(buffered, {
    style: {
      color: '#4A90E2',
      fillColor: '#4A90E2',
      fillOpacity: 0.4
    }
  }).addTo(map)
  return buffered
}
