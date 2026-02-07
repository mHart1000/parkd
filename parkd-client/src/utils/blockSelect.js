import * as turf from '@turf/turf'
import L from 'leaflet'
import { cardinalDirection, getBearing } from './freehandProcessing.js'

// Road types that count as real intersections (block boundaries)
const SIGNIFICANT_ROAD_TYPES = new Set([
  'primary', 'secondary', 'tertiary', 'residential', 'unclassified',
  'primary_link', 'secondary_link', 'tertiary_link', 'living_street'
])

// Road types to ignore (won't create block boundaries)
const IGNORED_ROAD_TYPES = new Set([
  'service', 'footway', 'cycleway', 'path', 'track', 'pedestrian',
  'steps', 'corridor', 'bridleway', 'construction'
])

// Minimum distance (meters) between intersections to be considered separate
const INTERSECTION_CLUSTER_THRESHOLD = 40

// Minimum block length (meters) to be valid
const MIN_BLOCK_LENGTH = 30

export async function handleBlockClick (e, overpassUrl, candidateLayers, $q, map, $emit, updateLayers) {
  const { lat, lng } = e.latlng

  candidateLayers = clearCandidateLayers(candidateLayers, map)

  // Query a wider radius to get full street context
  const res = await fetch(overpassUrl, {
    method: 'POST',
    body: `
          [out:json][timeout:25];
          way(around:250,${lat},${lng})["highway"];
          (._;>;);
          out geom tags;
        `
  })
  const data = await res.json()

  // Process and find the best block
  const result = computeSmartBlock(data, lat, lng)

  if (!result) {
    $q.notify({ type: 'warning', message: 'No block found here. Try tapping closer to a street.' })
    return candidateLayers
  }

  const { block, crossStreets, streetName } = result

  // Highlight the single auto-selected block
  const layer = L.geoJSON(block, {
    style: { color: '#4A90E2', weight: 8, opacity: 0.9 }
  }).addTo(map)

  candidateLayers.push(layer)

  // Show confirmation with cross-street names
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
 * Main logic: compute the single best block for the user's tap
 */
export function computeSmartBlock (data, lat, lng) {
  const ways = data.elements.filter(el => el.type === 'way' && el.geometry && el.tags)
  if (!ways.length) return null

  const clickPt = turf.point([lng, lat])

  // Step 1: Find the nearest significant road to the click
  const significantWays = ways.filter(w => {
    const hwType = w.tags?.highway
    return hwType && !IGNORED_ROAD_TYPES.has(hwType)
  })

  if (!significantWays.length) return null

  const ranked = significantWays.map(way => {
    const coords = way.geometry.map(pt => [pt.lon, pt.lat])
    const line = turf.lineString(coords)
    const dist = turf.pointToLineDistance(clickPt, line, { units: 'meters' })
    return { way, line, coords, dist, name: way.tags?.name || null }
  }).sort((a, b) => a.dist - b.dist)

  const target = ranked[0]
  const streetName = target.name || 'Unnamed street'

  // Step 2: Merge all ways with the same street name into one line
  const mergedLine = mergeStreetSegments(ranked.filter(r => r.name === target.name))

  // Step 3: Find intersections with OTHER named, significant streets
  const intersectingStreets = findSignificantIntersections(mergedLine, ranked, target.name)

  // Step 4: If we have at least 2 intersections, slice into blocks
  if (intersectingStreets.length < 2) {
    // Not enough intersections - return the whole merged street as one block
    return {
      block: mergedLine,
      crossStreets: [],
      streetName
    }
  }

  // Step 5: Cluster nearby intersections
  const clustered = clusterIntersections(intersectingStreets, mergedLine)

  // Step 6: Find which block contains the click point
  const blocks = buildBlocks(clustered, mergedLine)
  const selectedBlock = findBlockContainingPoint(blocks, clickPt, mergedLine)

  if (!selectedBlock) {
    // Fallback: return nearest block
    return {
      block: blocks[0]?.block || mergedLine,
      crossStreets: blocks[0]?.crossStreets || [],
      streetName
    }
  }

  return {
    block: selectedBlock.block,
    crossStreets: selectedBlock.crossStreets,
    streetName
  }
}

/**
 * Merge multiple way segments with the same name into one continuous line
 */
function mergeStreetSegments (segments) {
  if (segments.length === 0) return null
  if (segments.length === 1) return segments[0].line

  // Collect all coordinates
  const allCoords = []
  const used = new Set()

  // Start with the first segment
  const currentCoords = [...segments[0].coords]
  used.add(0)
  allCoords.push(...currentCoords)

  // Iteratively find and attach connected segments
  let changed = true
  while (changed) {
    changed = false
    for (let i = 0; i < segments.length; i++) {
      if (used.has(i)) continue

      const segCoords = segments[i].coords
      const segStart = segCoords[0]
      const segEnd = segCoords[segCoords.length - 1]
      const lineStart = allCoords[0]
      const lineEnd = allCoords[allCoords.length - 1]

      const tolerance = 0.00005 // ~5 meters
      const coordsMatch = (a, b) =>
        Math.abs(a[0] - b[0]) < tolerance && Math.abs(a[1] - b[1]) < tolerance

      if (coordsMatch(segEnd, lineStart)) {
        // Prepend segment (excluding last point which matches)
        allCoords.unshift(...segCoords.slice(0, -1))
        used.add(i)
        changed = true
      } else if (coordsMatch(segStart, lineEnd)) {
        // Append segment (excluding first point which matches)
        allCoords.push(...segCoords.slice(1))
        used.add(i)
        changed = true
      } else if (coordsMatch(segStart, lineStart)) {
        // Reverse and prepend
        allCoords.unshift(...segCoords.slice(1).reverse())
        used.add(i)
        changed = true
      } else if (coordsMatch(segEnd, lineEnd)) {
        // Reverse and append
        allCoords.push(...segCoords.slice(0, -1).reverse())
        used.add(i)
        changed = true
      }
    }
  }

  return turf.lineString(allCoords)
}

/**
 * Find intersections with significant, named cross-streets only
 */
function findSignificantIntersections (targetLine, allWays, targetStreetName) {
  const intersections = []

  for (const w of allWays) {
    // Skip the target street itself
    if (w.name === targetStreetName) continue

    // Only count significant road types
    const hwType = w.way.tags?.highway
    if (!SIGNIFICANT_ROAD_TYPES.has(hwType)) continue

    // Prefer named streets (unnamed = likely driveways/alleys)
    const crossStreetName = w.way.tags?.name
    if (!crossStreetName) continue

    const otherLine = w.line
    const fc = turf.lineIntersect(targetLine, otherLine)

    if (fc && fc.features.length) {
      for (const pt of fc.features) {
        intersections.push({
          point: pt,
          crossStreetName
        })
      }
    }
  }

  return intersections
}

/**
 * Cluster intersections that are close together (< threshold meters)
 */
function clusterIntersections (intersections, targetLine) {
  if (intersections.length === 0) return []

  // Project all intersections onto the line and sort by position
  const projected = intersections.map(int => {
    const nearestPt = turf.nearestPointOnLine(targetLine, int.point, { units: 'meters' })
    return {
      ...int,
      projected: nearestPt,
      location: nearestPt.properties.location
    }
  }).sort((a, b) => a.location - b.location)

  // Cluster nearby intersections
  const clustered = []
  let currentCluster = [projected[0]]

  for (let i = 1; i < projected.length; i++) {
    const prev = currentCluster[currentCluster.length - 1]
    const curr = projected[i]

    if (curr.location - prev.location < INTERSECTION_CLUSTER_THRESHOLD) {
      // Same cluster - add to it
      currentCluster.push(curr)
    } else {
      // New cluster - finalize previous and start new
      clustered.push(finalizeCluster(currentCluster))
      currentCluster = [curr]
    }
  }

  // Don't forget the last cluster
  clustered.push(finalizeCluster(currentCluster))

  return clustered
}

/**
 * Finalize a cluster: use average position and combine street names
 */
function finalizeCluster (cluster) {
  const avgLocation = cluster.reduce((sum, c) => sum + c.location, 0) / cluster.length

  // Get unique cross-street names in this cluster
  const names = [...new Set(cluster.map(c => c.crossStreetName))]

  return {
    location: avgLocation,
    projected: cluster[0].projected, // Use first point as representative
    crossStreetNames: names.join(' / ')
  }
}

/**
 * Build blocks between consecutive intersections
 */
function buildBlocks (clusteredIntersections, targetLine) {
  const blocks = []

  // Add start of line as implicit boundary
  const lineCoords = turf.getCoords(targetLine)
  const lineStart = turf.point(lineCoords[0])
  const lineEnd = turf.point(lineCoords[lineCoords.length - 1])

  const startProj = turf.nearestPointOnLine(targetLine, lineStart, { units: 'meters' })
  const endProj = turf.nearestPointOnLine(targetLine, lineEnd, { units: 'meters' })

  // Build full list of boundary points
  const boundaries = [
    { location: startProj.properties.location, projected: startProj, crossStreetNames: 'Street end' },
    ...clusteredIntersections,
    { location: endProj.properties.location, projected: endProj, crossStreetNames: 'Street end' }
  ].sort((a, b) => a.location - b.location)

  // Create blocks between consecutive boundaries
  for (let i = 0; i < boundaries.length - 1; i++) {
    const startBoundary = boundaries[i]
    const endBoundary = boundaries[i + 1]

    // Skip if block is too short
    const blockLength = endBoundary.location - startBoundary.location
    if (blockLength < MIN_BLOCK_LENGTH) continue

    try {
      const sliced = turf.lineSlice(startBoundary.projected, endBoundary.projected, targetLine)
      const coords = turf.getCoords(sliced)

      if (coords.length >= 2) {
        blocks.push({
          block: sliced,
          crossStreets: [startBoundary.crossStreetNames, endBoundary.crossStreetNames],
          startLocation: startBoundary.location,
          endLocation: endBoundary.location
        })
      }
    } catch (e) {
      // lineSlice can fail with edge cases, skip this block
      console.warn('Failed to slice block:', e)
    }
  }

  return blocks
}

/**
 * Find which block contains (or is nearest to) the click point
 */
function findBlockContainingPoint (blocks, clickPt, targetLine) {
  if (blocks.length === 0) return null
  if (blocks.length === 1) return blocks[0]

  // Project click point onto the target line
  const clickProj = turf.nearestPointOnLine(targetLine, clickPt, { units: 'meters' })
  const clickLocation = clickProj.properties.location

  // Find the block that contains this location
  for (const b of blocks) {
    if (clickLocation >= b.startLocation && clickLocation <= b.endLocation) {
      return b
    }
  }

  // Fallback: find nearest block
  let nearest = blocks[0]
  let nearestDist = Infinity

  for (const b of blocks) {
    const midpoint = (b.startLocation + b.endLocation) / 2
    const dist = Math.abs(clickLocation - midpoint)
    if (dist < nearestDist) {
      nearestDist = dist
      nearest = b
    }
  }

  return nearest
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

  // Compute center and simple direction
  const center = turf.center(block).geometry.coordinates
  const absBearing = getBearing(block)

  // Reverse geocode center for address
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

  // Use provided street name or fall back to geocoded
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

  // turn off block-select mode after confirmation
  $emit('update:blockSelectActive', false)

  return []
}
