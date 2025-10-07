// src/utils/freehandLine.js
import L from 'leaflet'

export const createFreehandLine = (map, { onFinish } = {}) => {
  let active = false
  let polyline = null
  let prev = null

  const stopEvent = evt => {
    const e = evt && (evt.originalEvent || evt)
    if (!e) return
    L.DomEvent.stop(e)
  }

  const disableMapInteractions = () => {
    prev = {
      dragging: map.dragging && map.dragging.enabled && map.dragging.enabled(),
      touchZoom: map.touchZoom && map.touchZoom.enabled && map.touchZoom.enabled(),
      scrollWheelZoom: map.scrollWheelZoom && map.scrollWheelZoom.enabled && map.scrollWheelZoom.enabled(),
      boxZoom: map.boxZoom && map.boxZoom.enabled && map.boxZoom.enabled(),
      doubleClickZoom: map.doubleClickZoom && map.doubleClickZoom.enabled && map.doubleClickZoom.enabled(),
      keyboard: map.keyboard && map.keyboard.enabled && map.keyboard.enabled()
    }

    if (map.dragging && map.dragging.disable) map.dragging.disable()
    if (map.touchZoom && map.touchZoom.disable) map.touchZoom.disable()
    if (map.scrollWheelZoom && map.scrollWheelZoom.disable) map.scrollWheelZoom.disable()
    if (map.boxZoom && map.boxZoom.disable) map.boxZoom.disable()
    if (map.doubleClickZoom && map.doubleClickZoom.disable) map.doubleClickZoom.disable()
    if (map.keyboard && map.keyboard.disable) map.keyboard.disable()

    if (map._container) map._container.style.cursor = 'crosshair'
  }

  const restoreMapInteractions = () => {
    if (!prev) return

    if (map.dragging && map.dragging.enable && prev.dragging) map.dragging.enable()
    if (map.touchZoom && map.touchZoom.enable && prev.touchZoom) map.touchZoom.enable()
    if (map.scrollWheelZoom && map.scrollWheelZoom.enable && prev.scrollWheelZoom) map.scrollWheelZoom.enable()
    if (map.boxZoom && map.boxZoom.enable && prev.boxZoom) map.boxZoom.enable()
    if (map.doubleClickZoom && map.doubleClickZoom.enable && prev.doubleClickZoom) map.doubleClickZoom.enable()
    if (map.keyboard && map.keyboard.enable && prev.keyboard) map.keyboard.enable()

    if (map._container) map._container.style.cursor = ''
    prev = null
  }

  const onDown = e => {
    if (!active) return
    stopEvent(e)

    const start = e.latlng
    if (!start) return

    disableMapInteractions()

    polyline = L.polyline([start], {
      color: '#4A90E2',
      weight: 4,
      opacity: 1
    }).addTo(map)

    map.on('mousemove', onMove)
    map.on('touchmove', onMove)
    map.on('mouseup', onUp)
    map.on('touchend', onUp)
  }

  const onMove = e => {
    if (!polyline) return
    stopEvent(e)
    const ll = e.latlng
    if (!ll) return
    polyline.addLatLng(ll)
  }

  const onUp = async e => {
    stopEvent(e)

    map.off('mousemove', onMove)
    map.off('touchmove', onMove)
    map.off('mouseup', onUp)
    map.off('touchend', onUp)

    const layer = polyline
    polyline = null

    restoreMapInteractions()

    if (!layer) return

    const geojson = layer.toGeoJSON()
    if (typeof onFinish === 'function') {
      try {
        await onFinish(geojson, layer)
      } catch (err) {
        console.error('[freehandLine] onFinish error:', err)
      }
    }
  }

  const enable = () => {
    if (active) return
    active = true
    map.on('mousedown', onDown)
    map.on('touchstart', onDown)
  }

  const disable = () => {
    if (!active) return
    active = false
    map.off('mousedown', onDown)
    map.off('touchstart', onDown)
    map.off('mousemove', onMove)
    map.off('touchmove', onMove)
    map.off('mouseup', onUp)
    map.off('touchend', onUp)

    if (polyline) {
      map.removeLayer(polyline)
      polyline = null
    }
    restoreMapInteractions()
  }

  const isActive = () => active

  return { enable, disable, isActive }
}
