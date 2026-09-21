import React, { useEffect, useId, useMemo, useRef } from 'react'

const GOOGLE_MAPS_KEY =
  (typeof import.meta !== 'undefined' && import.meta.env?.VITE_GOOGLE_MAPS_API_KEY) || ''

const toValidPoints = (points = []) =>
  (Array.isArray(points) ? points : [])
    .map((p, idx) => ({
      lat: Number(p.latitude ?? p.lat),
      lng: Number(p.longitude ?? p.lng ?? p.lon),
      label: p.label || p.visitorName || p.address || `Stop ${idx + 1}`,
      type: p.type || p.source || 'check_in',
    }))
    .filter((p) => Number.isFinite(p.lat) && Number.isFinite(p.lng))

const toTrackPath = (trackPoints = []) =>
  (Array.isArray(trackPoints) ? trackPoints : [])
    .map((p) => ({
      lat: Number(p.latitude ?? p.lat),
      lng: Number(p.longitude ?? p.lng ?? p.lon),
      source: p.source || 'track',
      recordedAt: p.recordedAt,
    }))
    .filter((p) => Number.isFinite(p.lat) && Number.isFinite(p.lng))

/** Google Maps Embed Directions URL (requires Maps Embed API key). */
export const buildGoogleMapsEmbedUrl = (points = [], apiKey = GOOGLE_MAPS_KEY) => {
  if (!apiKey) return null
  const valid = toValidPoints(points)
  if (!valid.length) return null

  if (valid.length === 1) {
    return `https://www.google.com/maps/embed/v1/place?key=${encodeURIComponent(apiKey)}&q=${valid[0].lat},${valid[0].lng}&zoom=14`
  }

  const origin = `${valid[0].lat},${valid[0].lng}`
  const destination = `${valid[valid.length - 1].lat},${valid[valid.length - 1].lng}`
  const mid = valid.slice(1, -1).slice(0, 10)
  const waypoints = mid.map((p) => `${p.lat},${p.lng}`).join('|')

  let url = `https://www.google.com/maps/embed/v1/directions?key=${encodeURIComponent(apiKey)}&origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&mode=driving`
  if (waypoints) url += `&waypoints=${encodeURIComponent(waypoints)}`
  return url
}

let leafletLoader = null
const loadLeaflet = () => {
  if (typeof window === 'undefined') return Promise.reject(new Error('No window'))
  if (window.L) return Promise.resolve(window.L)
  if (leafletLoader) return leafletLoader

  leafletLoader = new Promise((resolve, reject) => {
    const cssId = 'leaflet-cdn-css'
    if (!document.getElementById(cssId)) {
      const link = document.createElement('link')
      link.id = cssId
      link.rel = 'stylesheet'
      link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'
      document.head.appendChild(link)
    }

    const existing = document.getElementById('leaflet-cdn-js')
    if (existing) {
      existing.addEventListener('load', () => resolve(window.L))
      existing.addEventListener('error', () => reject(new Error('Failed to load Leaflet')))
      if (window.L) resolve(window.L)
      return
    }

    const script = document.createElement('script')
    script.id = 'leaflet-cdn-js'
    script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'
    script.async = true
    script.onload = () => resolve(window.L)
    script.onerror = () => reject(new Error('Failed to load Leaflet'))
    document.body.appendChild(script)
  })

  return leafletLoader
}

const markerLabel = (p, idx, total) => {
  if (p.type === 'journey_start' || p.source === 'journey_start') return 'Journey start'
  if (p.type === 'journey_end' || p.source === 'journey_end') return 'Journey end'
  if (idx === 0) return 'Start'
  if (idx === total - 1 && total > 1) return 'Last stop'
  return p.label || `Stop ${idx + 1}`
}

/**
 * Route map: draws the actual GPS trail when trackPoints exist.
 * Important stops (journey start, check-ins, journey end) show as markers on the timeline.
 */
const TravelRouteMap = ({
  points = [],
  trackPoints = [],
  routeUrl = null,
  height = 360,
  emptyMessage = 'No route points yet.',
}) => {
  const mapHostId = useId().replace(/:/g, '')
  const mapRef = useRef(null)
  const mapInstanceRef = useRef(null)
  const valid = useMemo(() => toValidPoints(points), [points])
  const trail = useMemo(() => toTrackPath(trackPoints), [trackPoints])
  const hasGpsTrail = trail.length >= 2
  const embedUrl = useMemo(
    () => (hasGpsTrail ? null : buildGoogleMapsEmbedUrl(valid)),
    [hasGpsTrail, valid]
  )

  useEffect(() => {
    if (embedUrl || (!valid.length && !trail.length) || !mapRef.current) return undefined

    let cancelled = false

    loadLeaflet()
      .then((L) => {
        if (cancelled || !mapRef.current) return

        if (mapInstanceRef.current) {
          mapInstanceRef.current.remove()
          mapInstanceRef.current = null
        }

        const map = L.map(mapRef.current, {
          scrollWheelZoom: false,
          zoomControl: true,
        })
        mapInstanceRef.current = map

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          attribution: '&copy; OpenStreetMap',
          maxZoom: 19,
        }).addTo(map)

        const allLatLngs = []

        if (hasGpsTrail) {
          const path = trail.map((p) => [p.lat, p.lng])
          allLatLngs.push(...path)
          L.polyline(path, { color: '#2563eb', weight: 5, opacity: 0.9 }).addTo(map)
        } else if (valid.length > 1) {
          const path = valid.map((p) => [p.lat, p.lng])
          allLatLngs.push(...path)
          L.polyline(path, { color: '#94a3b8', weight: 3, opacity: 0.6, dashArray: '6 8' }).addTo(map)
        }

        valid.forEach((p, idx) => {
          allLatLngs.push([p.lat, p.lng])
          const isStart = p.type === 'journey_start'
          const isEnd = p.type === 'journey_end'
          const isCheckIn = p.type === 'check_in'
          const color = isStart || isEnd ? '#0f172a' : isCheckIn ? '#4f46e5' : '#64748b'
          const marker = L.circleMarker([p.lat, p.lng], {
            radius: isStart || isEnd ? 9 : 7,
            color: '#fff',
            weight: 2,
            fillColor: color,
            fillOpacity: 1,
          }).addTo(map)
          marker.bindPopup(
            `<strong>${markerLabel(p, idx, valid.length)}</strong><br/>${p.label || ''}`
          )
        })

        if (!allLatLngs.length) return

        if (allLatLngs.length === 1) {
          map.setView(allLatLngs[0], 14)
        } else {
          map.fitBounds(L.latLngBounds(allLatLngs).pad(0.2))
        }

        setTimeout(() => map.invalidateSize(), 80)
      })
      .catch(() => {
        /* ignore — empty state handled below */
      })

    return () => {
      cancelled = true
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove()
        mapInstanceRef.current = null
      }
    }
  }, [embedUrl, valid, trail, hasGpsTrail, mapHostId])

  if (!valid.length && !trail.length) {
    return (
      <div
        className='flex items-center justify-center bg-slate-50 text-sm text-gray-500 rounded-b-xl'
        style={{ minHeight: height }}
      >
        {emptyMessage}
      </div>
    )
  }

  return (
    <div className='relative'>
      {embedUrl ? (
        <iframe
          title='Google Maps travel route'
          src={embedUrl}
          className='w-full border-0 block'
          style={{ height }}
          loading='lazy'
          referrerPolicy='no-referrer-when-downgrade'
          allowFullScreen
        />
      ) : (
        <div
          id={`travel-route-map-${mapHostId}`}
          ref={mapRef}
          className='w-full z-0'
          style={{ height }}
        />
      )}
      <div className='absolute bottom-3 right-3 z-[500] flex flex-wrap gap-2'>
        {routeUrl ? (
          <a
            href={routeUrl}
            target='_blank'
            rel='noopener noreferrer'
            className='rounded-lg bg-white/95 border border-gray-200 px-3 py-1.5 text-xs font-semibold text-indigo-700 shadow-sm hover:bg-white'
          >
            Open stops in Google Maps
          </a>
        ) : null}
      </div>
      {!embedUrl ? (
        <p className='px-4 py-2 text-[11px] text-gray-500 border-t border-gray-100 bg-white'>
          {hasGpsTrail
            ? 'Blue line = your actual GPS path while journey is active. Markers = important stops on the timeline.'
            : 'GPS trail will appear here once you start moving. Markers show journey start and check-ins.'}
        </p>
      ) : null}
    </div>
  )
}

export default TravelRouteMap
