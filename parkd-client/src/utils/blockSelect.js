import * as turf from '@turf/turf'
import L from 'leaflet'
import { cardinalDirection, getBearing } from './freehandProcessing.js'

export async function handleBlockClick (e, overpassUrl, candidateLayers, $q, map, $emit, updateLayers) {
  const { lat, lng } = e.latlng

  candidateLayers = clearCandidateLayers(candidateLayers, map)

  const res = await fetch(overpassUrl, {
    method: 'POST',
    body: `
          [out:json][timeout:25];
          way(around:100,${lat},${lng})["highway"];
          (._;>;);
          out geom;
        `
  })
  const data = await res.json()

  const blocks = computeCandidateBlocks(data, lat, lng)

  blocks.forEach(block => {
    const layer = L.geoJSON(block, {
      style: { color: '#ff6600', weight: 6, opacity: 0.5 }
    }).addTo(map)

    layer.on('click', async () => {
      candidateLayers = await confirmBlock(block, candidateLayers, map, $q, $emit)
      if (typeof updateLayers === 'function') {
        updateLayers(candidateLayers) // sync Vue's this.candidateLayers
      }
    })
    candidateLayers.push(layer)
  })

  if (blocks.length) {
    $q.notify({ type: 'info', message: 'Select a highlighted block' })
  } else {
    $q.notify({ type: 'warning', message: 'No blocks found here' })
  }
  return candidateLayers
}

export function computeCandidateBlocks (data, lat, lng) {
  const ways = data.elements.filter(el => el.type === 'way' && el.geometry)
  if (!ways.length) return []

  const clickPt = turf.point([lng, lat])
  console.log('Click point:', clickPt)
  console.log('Ways:', ways)
  console.log('Number of ways:', ways.length)
  console.log('lat:', lat, 'lng:', lng)
  // Pick nearest road to click
  const ranked = ways.map(way => {
    const coords = way.geometry.map(pt => [pt.lon, pt.lat])
    const line = turf.lineString(coords)
    const dist = turf.pointToLineDistance(clickPt, line, { units: 'meters' })
    return { way, line, coords, dist }
  }).sort((a, b) => a.dist - b.dist)

  const target = ranked[0]
  const targetLine = target.line

  // Intersections with other roads
  const intersections = []
  for (const w of ranked.slice(1)) {
    const otherLine = turf.lineString(w.coords)
    const fc = turf.lineIntersect(targetLine, otherLine)
    if (fc && fc.features.length) intersections.push(...fc.features)
  }

  // Deduplicate intersections
  const seen = new Set()
  const unique = intersections.filter(pt => {
    const [x, y] = pt.geometry.coordinates
    const key = `${x.toFixed(6)},${y.toFixed(6)}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })

  if (unique.length < 2) return []

  // Project intersections along target line
  const projected = unique.map(pt =>
    turf.nearestPointOnLine(targetLine, pt, { units: 'meters' })
  ).sort((a, b) => a.properties.location - b.properties.location)

  // Build blocks between pairs
  const blocks = []
  for (let i = 0; i < projected.length - 1; i++) {
    const sliced = turf.lineSlice(projected[i], projected[i + 1], targetLine)
    if (turf.getCoords(sliced).length >= 2) blocks.push(sliced)
  }

  return blocks
}

export function clearCandidateLayers (candidateLayers = [], map) {
  candidateLayers.forEach(l => map.removeLayer(l))
  return []
}

export async function confirmBlock (block, candidateLayers, map, $q, $emit) {
  clearCandidateLayers(candidateLayers, map)

  L.geoJSON(block, {
    style: { color: '#4A90E2', weight: 6, opacity: 0.9 }
  }).addTo(map)

  // Compute center and simple direction
  const center = turf.center(block).geometry.coordinates
  const absBearing = getBearing(block)

  // Reverse geocode center for address and street name
  let address = {}
  try {
    const [lng, lat] = center
    const ua = (import.meta && import.meta.env && import.meta.env.VITE_CLIENT_USER_AGENT) || 'parkd-app'
    const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}`, {
      headers: { 'User-Agent': ua }
    })
    const data = await res.json()
    address = data.address || {}
  } catch (e) {
    // ignore, keep empty address
  }

  $emit('shape-drawn', {
    segment: block,
    geojson: block,
    center,
    address,
    streetName: address.road || address.street || '',
    streetDirection: cardinalDirection(absBearing)
  })
  $q.notify({ type: 'positive', message: 'Block selected!' })

  // turn off block-select mode after confirmation
  $emit('update:blockSelectActive', false)

  return []
}
