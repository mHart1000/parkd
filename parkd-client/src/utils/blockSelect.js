import * as turf from '@turf/turf'
import L from 'leaflet'
import { cardinalDirection, getBearing } from './freehandProcessing.js'

const SIGNIFICANT_ROAD_TYPES = new Set([
  'primary', 'secondary', 'tertiary', 'residential', 'unclassified',
  'primary_link', 'secondary_link', 'tertiary_link', 'living_street'
])

const IGNORED_ROAD_TYPES = new Set([
  'service', 'footway', 'cycleway', 'path', 'track', 'pedestrian',
  'steps', 'corridor', 'bridleway', 'construction'
])

export async function handleBlockClick (e, overpassUrl, candidateLayers, $q, map, $emit, updateLayers) {
  const { lat, lng } = e.latlng

  candidateLayers = clearCandidateLayers(candidateLayers, map)

  const res = await fetch(overpassUrl, {
    method: 'POST',
    body: `
          [out:json][timeout:25];
          way(around:250,${lat},${lng})["highway"];
          (._;>;);
          out;
        `
  })
  const data = await res.json()

  const result = computeSmartBlock(data, lat, lng)

  if (!result) {
    $q.notify({ type: 'warning', message: 'No block found here. Try tapping closer to a street.' })
    return candidateLayers
  }

  const { block, crossStreets, streetName } = result

  const layer = L.geoJSON(block, {
    style: { color: '#4A90E2', weight: 8, opacity: 0.9 }
  }).addTo(map)

  candidateLayers.push(layer)

  const crossStreetText = crossStreets.length === 2
    ? `${streetName} between ${crossStreets[0]} and ${crossStreets[1]}`
    : streetName

  $q.notify({
    type: 'info',
    message: crossStreetText,
    caption: 'Tap again to change, or confirm below',
    timeout: 5000,
    actions: [
      {
        label: 'Confirm',
        color: 'white',
        handler: async () => {
          await confirmBlock(block, candidateLayers, map, $q, $emit, crossStreets, streetName)
          if (typeof updateLayers === 'function') {
            updateLayers([])
          }
        }
      }
    ]
  })

  return candidateLayers
}

/**
 * Compute the block containing the click by walking the OSM way graph using
 * shared node IDs. An intersection is a node shared with another significant
 * way whose name differs from the click-way's name. Same-named ways meeting at
 * a node are treated as continuations (the walk hops onto them).
 */
export function computeSmartBlock (data, lat, lng) {
  if (!data || !Array.isArray(data.elements) || !data.elements.length) return null

  const nodesById = new Map()
  const ways = []
  for (const el of data.elements) {
    if (el.type === 'node') {
      nodesById.set(el.id, { lat: el.lat, lon: el.lon })
    } else if (el.type === 'way' && Array.isArray(el.nodes) && el.tags) {
      const hwType = el.tags.highway
      if (hwType && !IGNORED_ROAD_TYPES.has(hwType)) {
        ways.push(el)
      }
    }
  }

  if (!ways.length) return null

  const waysByNode = new Map()
  for (const w of ways) {
    for (const nodeId of w.nodes) {
      if (!waysByNode.has(nodeId)) waysByNode.set(nodeId, [])
      waysByNode.get(nodeId).push(w)
    }
  }

  const wayGeom = new Map()
  for (const w of ways) {
    const coords = []
    let ok = true
    for (const nodeId of w.nodes) {
      const n = nodesById.get(nodeId)
      if (!n) { ok = false; break }
      coords.push([n.lon, n.lat])
    }
    if (ok && coords.length >= 2) {
      wayGeom.set(w.id, { line: turf.lineString(coords), coords })
    }
  }

  const clickPt = turf.point([lng, lat])
  let nearest = null
  let nearestDist = Infinity
  for (const w of ways) {
    const geom = wayGeom.get(w.id)
    if (!geom) continue
    const dist = turf.pointToLineDistance(clickPt, geom.line, { units: 'meters' })
    if (dist < nearestDist) {
      nearestDist = dist
      nearest = w
    }
  }

  if (!nearest) return null

  const streetName = nearest.tags?.name || 'Unnamed street'
  const nearestCoords = wayGeom.get(nearest.id).coords

  // Bracket the click: find the segment [i, i+1] on the way closest to the click point
  let bracketLow = 0
  let bracketHigh = Math.min(1, nearestCoords.length - 1)
  let minSegDist = Infinity
  for (let i = 0; i < nearestCoords.length - 1; i++) {
    const seg = turf.lineString([nearestCoords[i], nearestCoords[i + 1]])
    const d = turf.pointToLineDistance(clickPt, seg, { units: 'meters' })
    if (d < minSegDist) {
      minSegDist = d
      bracketLow = i
      bracketHigh = i + 1
    }
  }

  const forward = walkToBoundary(nearest, bracketHigh, 1, waysByNode, nodesById)
  const backward = walkToBoundary(nearest, bracketLow, -1, waysByNode, nodesById)

  // Assemble: backward coords reversed (from backward-boundary in toward bracketLow)
  // + forward coords (from bracketHigh out toward forward-boundary)
  const fullCoords = [...backward.coords.slice().reverse(), ...forward.coords]
  if (fullCoords.length < 2) return null

  return {
    block: turf.lineString(fullCoords),
    crossStreets: [backward.label, forward.label],
    streetName
  }
}

/**
 * Walk along way.nodes from startIdx in `direction` (±1) until we hit a
 * boundary node (intersection with a different-named significant way) or end
 * of way (unless a same-named way continues, in which case hop to it).
 *
 * Returns { coords, label } — coords is the list of [lon, lat] from the start
 * node outward to the boundary node (inclusive); label is the cross-street
 * name, 'unnamed street', or 'street end'.
 */
function walkToBoundary (startWay, startIdx, direction, waysByNode, nodesById) {
  const coords = []
  let currentWay = startWay
  let currentName = currentWay.tags?.name || null
  let idx = startIdx

  const startNode = nodesById.get(currentWay.nodes[idx])
  if (startNode) coords.push([startNode.lon, startNode.lat])

  // The starting node itself may already be an intersection (user clicked
  // right next to one). If so, stop here — the block on this side has zero
  // length and is bounded by that intersection.
  const startIncident = intersectionWaysAt(currentWay.nodes[idx], currentWay, currentName, waysByNode)
  if (startIncident.length) {
    return { coords, label: resolveIncidentLabel(startIncident) }
  }

  const visitedWays = new Set([currentWay.id])

  while (true) {
    const nextIdx = idx + direction
    if (nextIdx < 0 || nextIdx >= currentWay.nodes.length) {
      const endNodeId = currentWay.nodes[idx]
      const continuation = findSameNameContinuation(endNodeId, currentWay, currentName, waysByNode, visitedWays)
      if (continuation) {
        currentWay = continuation.way
        visitedWays.add(currentWay.id)
        idx = continuation.idx
        direction = continuation.direction
        currentName = currentWay.tags?.name || currentName
        continue
      }
      return { coords, label: 'street end' }
    }

    const nextNodeId = currentWay.nodes[nextIdx]
    const nextNode = nodesById.get(nextNodeId)
    if (nextNode) coords.push([nextNode.lon, nextNode.lat])

    const incident = intersectionWaysAt(nextNodeId, currentWay, currentName, waysByNode)
    if (incident.length) {
      return { coords, label: resolveIncidentLabel(incident) }
    }

    idx = nextIdx
  }
}

function intersectionWaysAt (nodeId, currentWay, currentName, waysByNode) {
  return (waysByNode.get(nodeId) || [])
    .filter(w => w.id !== currentWay.id)
    .filter(w => SIGNIFICANT_ROAD_TYPES.has(w.tags?.highway))
    .filter(w => {
      const n = w.tags?.name || null
      // Different-named (or unnamed) significant way = real intersection
      return n !== currentName || (!n && !currentName)
    })
}

function findSameNameContinuation (nodeId, currentWay, currentName, waysByNode, visitedWays) {
  if (!currentName) return null
  const candidates = (waysByNode.get(nodeId) || [])
    .filter(w => w.id !== currentWay.id && !visitedWays.has(w.id))
    .filter(w => (w.tags?.name || null) === currentName)
  if (!candidates.length) return null
  const next = candidates[0]
  const newIdx = next.nodes.indexOf(nodeId)
  if (newIdx < 0) return null
  // If the shared node is at the start of the new way, walk forward; if at the
  // end, walk backward. Otherwise (shared node mid-way), pick forward.
  const direction = newIdx === next.nodes.length - 1 ? -1 : 1
  return { way: next, idx: newIdx, direction }
}

function resolveIncidentLabel (incidentWays) {
  const names = [...new Set(incidentWays.map(w => w.tags?.name).filter(Boolean))]
  if (!names.length) return 'unnamed street'
  return names.join(' / ')
}

export function clearCandidateLayers (candidateLayers = [], map) {
  candidateLayers.forEach(l => map.removeLayer(l))
  return []
}

export async function confirmBlock (block, candidateLayers, map, $q, $emit, crossStreets = [], streetName = '') {
  clearCandidateLayers(candidateLayers, map)

  L.geoJSON(block, {
    style: { color: '#4A90E2', weight: 8, opacity: 0.9 }
  }).addTo(map)

  const center = turf.center(block).geometry.coordinates
  const absBearing = getBearing(block)

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

  const finalStreetName = streetName || address.road || address.street || ''

  $emit('shape-drawn', {
    segment: block,
    geojson: block,
    center,
    address,
    streetName: finalStreetName,
    streetDirection: cardinalDirection(absBearing),
    crossStreets
  })

  const confirmMsg = crossStreets.length === 2
    ? `${finalStreetName} between ${crossStreets[0]} and ${crossStreets[1]}`
    : 'Block selected!'

  $q.notify({ type: 'positive', message: confirmMsg })

  $emit('update:blockSelectActive', false)

  return []
}
