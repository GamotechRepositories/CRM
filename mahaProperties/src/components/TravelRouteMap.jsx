import React, { useEffect, useId, useMemo, useRef, useState } from 'react'

const GOOGLE_MAPS_KEY =
  (typeof import.meta !== 'undefined' && import.meta.env?.VITE_GOOGLE_MAPS_API_KEY) || ''

export const toValidPoints = (points = []) =>
  (Array.isArray(points) ? points : [])
    .map((p, idx) => ({
      lat: Number(p.latitude ?? p.lat),
      lng: Number(p.longitude ?? p.lng ?? p.lon),
      label: p.label || p.name || p.visitorName || p.address || `Stop ${idx + 1}`,
      type: p.type || p.source || 'check_in',
      address: p.address || '',
      arrivalTime: p.arrivalTime || p.checkInAt || null,
      departureTime: p.departureTime || p.checkOutAt || null,
      stopNumber: p.stopNumber || idx + 1,
    }))
    .filter((p) => Number.isFinite(p.lat) && Number.isFinite(p.lng))

export const toTrackPath = (trackPoints = []) =>
  (Array.isArray(trackPoints) ? trackPoints : [])
    .map((p) => ({
      lat: Number(p.latitude ?? p.lat),
      lng: Number(p.longitude ?? p.lng ?? p.lon),
      source: p.source || 'track',
      recordedAt: p.recordedAt,
    }))
    .filter((p) => Number.isFinite(p.lat) && Number.isFinite(p.lng))

/**
 * Client-side road routing via OpenStreetMap OSRM driving engine.
 * Calculates exact road geometry along streets, driving distance, duration, and road names.
 */
export const fetchClientDrivingRoute = async (points = []) => {
  const valid = toValidPoints(points)
  if (valid.length < 2) return null

  let sampled = valid
  if (valid.length > 25) {
    sampled = [valid[0]]
    const step = (valid.length - 2) / 23
    for (let i = 1; i <= 23; i += 1) {
      sampled.push(valid[Math.round(i * step)])
    }
    sampled.push(valid[valid.length - 1])
  }

  const coordStr = sampled.map((p) => `${p.lng},${p.lat}`).join(';')
  const url = `https://router.project-osrm.org/route/v1/driving/${coordStr}?overview=full&geometries=geojson&steps=true&annotations=true`

  try {
    const res = await fetch(url)
    if (!res.ok) return null
    const data = await res.json()
    const route = data?.routes?.[0]
    if (!route) return null

    const roadNamesSet = new Set()
    ;(route.legs || []).forEach((leg) => {
      ;(leg.steps || []).forEach((step) => {
        const name = String(step?.name || '').trim()
        if (name && !name.toLowerCase().startsWith('unnamed')) {
          roadNamesSet.add(name)
        }
      })
    })
    const roadNames = Array.from(roadNamesSet)
    const legSummaries = (route.legs || [])
      .map((l) => l.summary)
      .filter(Boolean)
      .join(', ')

    const routeSummary =
      legSummaries || (roadNames.length ? roadNames.slice(0, 3).join(', ') : 'Direct road route')
    const routeUsed = routeSummary ? `Via ${routeSummary}` : 'Driving road route'

    const roadCoordinates = (route.geometry?.coordinates || []).map(([lon, lat]) => [lat, lon])

    return {
      distanceKm: Math.round(((route.distance || 0) / 1000) * 100) / 100,
      durationMinutes: Math.round((route.duration || 0) / 60),
      routeUsed,
      routeSummary,
      roadNames,
      roadCoordinates,
    }
  } catch {
    return null
  }
}

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
 * Route map: draws the actual road route along streets and highways.
 * Calculates and displays:
 * 1. Road driving path (never straight-line Euclidean shortcut)
 * 2. Total road distance
 * 3. What route is used (e.g. "Via Western Express Hwy, SV Road") and road names.
 */
const TravelRouteMap = ({
  points = [],
  trackPoints = [],
  routeCoordinates = [],
  routeUsed: initialRouteUsed = '',
  routeSummary: initialRouteSummary = '',
  roadNames: initialRoadNames = [],
  routeUrl = null,
  height = 380,
  emptyMessage = 'No route points yet.',
  onRouteDetails = null,
}) => {
  const mapHostId = useId().replace(/:/g, '')
  const mapRef = useRef(null)
  const mapInstanceRef = useRef(null)
  const valid = useMemo(() => toValidPoints(points), [points])
  const trail = useMemo(() => toTrackPath(trackPoints), [trackPoints])
  const hasGpsTrail = trail.length >= 2

  const [roadRoute, setRoadRoute] = useState(null)
  const [routeLoading, setRouteLoading] = useState(false)

  // Fetch or resolve actual driving road route along streets
  useEffect(() => {
    let cancelled = false

    // If server already provided roadCoordinates
    if (Array.isArray(routeCoordinates) && routeCoordinates.length >= 2) {
      const coords = routeCoordinates.map((c) => [
        Number(c.latitude ?? c.lat),
        Number(c.longitude ?? c.lng),
      ])
      setRoadRoute({
        roadCoordinates: coords,
        routeUsed: initialRouteUsed,
        routeSummary: initialRouteSummary,
        roadNames: initialRoadNames,
        distanceKm: null,
      })
      return undefined
    }

    // Need at least 2 points to route
    const sourcePoints = valid.length >= 2 ? valid : (trail.length >= 2 ? trail : [])
    if (sourcePoints.length < 2) {
      setRoadRoute(null)
      return undefined
    }

    setRouteLoading(true)
    fetchClientDrivingRoute(sourcePoints).then((res) => {
      if (cancelled) return
      setRouteLoading(false)
      if (res) {
        setRoadRoute(res)
        if (typeof onRouteDetails === 'function') {
          onRouteDetails(res)
        }
      }
    })

    return () => {
      cancelled = true
    }
  }, [
    valid,
    trail,
    routeCoordinates,
    initialRouteUsed,
    initialRouteSummary,
    initialRoadNames,
    onRouteDetails,
  ])

  // Active route details to show
  const activeRouteUsed = roadRoute?.routeUsed || initialRouteUsed || ''
  const activeRoadNames = roadRoute?.roadNames?.length ? roadRoute.roadNames : (initialRoadNames || [])
  const activeDistanceKm = roadRoute?.distanceKm

  useEffect(() => {
    if ((!valid.length && !trail.length) || !mapRef.current) return undefined

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

        // 1. Draw Road-Matched Route Geometry if available
        if (roadRoute?.roadCoordinates?.length >= 2) {
          allLatLngs.push(...roadRoute.roadCoordinates)
          // Soft glow shadow
          L.polyline(roadRoute.roadCoordinates, {
            color: '#3b82f6',
            weight: 7,
            opacity: 0.35,
            lineJoin: 'round',
          }).addTo(map)
          // Main driving line
          L.polyline(roadRoute.roadCoordinates, {
            color: '#1d4ed8',
            weight: 5,
            opacity: 0.95,
            lineJoin: 'round',
          }).addTo(map)
        } else if (hasGpsTrail) {
          // 2. Draw dense GPS breadcrumb trail
          const path = trail.map((p) => [p.lat, p.lng])
          allLatLngs.push(...path)
          L.polyline(path, { color: '#2563eb', weight: 5, opacity: 0.9, lineJoin: 'round' }).addTo(map)
        } else if (valid.length > 1) {
          // 3. Fallback connecting path while routing loads
          const path = valid.map((p) => [p.lat, p.lng])
          allLatLngs.push(...path)
          L.polyline(path, { color: '#3b82f6', weight: 4, opacity: 0.7, dashArray: '4 6' }).addTo(map)
        }

        // Draw Stop Markers (Start, Visits, End)
        valid.forEach((p, idx) => {
          allLatLngs.push([p.lat, p.lng])
          const isStart = p.type === 'journey_start'
          const isEnd = p.type === 'journey_end'
          const isCheckIn = p.type === 'check_in' || p.type === 'site_visit'
          const color = isStart ? '#059669' : isEnd ? '#dc2626' : isCheckIn ? '#4f46e5' : '#475569'

          const marker = L.circleMarker([p.lat, p.lng], {
            radius: isStart || isEnd ? 9 : 7,
            color: '#ffffff',
            weight: 2.5,
            fillColor: color,
            fillOpacity: 1,
          }).addTo(map)

          const popupContent = `
            <div style="font-family: system-ui, sans-serif; font-size: 12px; line-height: 1.4; padding: 2px;">
              <strong style="color: ${color}; font-size: 13px;">${markerLabel(p, idx, valid.length)}</strong>
              ${p.label ? `<div style="margin-top: 2px; font-weight: 600; color: #1e293b;">${p.label}</div>` : ''}
              ${p.address ? `<div style="color: #64748b; font-size: 11px; margin-top: 2px;">${p.address}</div>` : ''}
              ${p.arrivalTime ? `<div style="color: #059669; font-size: 11px; margin-top: 3px;">Arrival: ${new Date(p.arrivalTime).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}</div>` : ''}
            </div>
          `
          marker.bindPopup(popupContent)
        })

        if (!allLatLngs.length) return

        if (allLatLngs.length === 1) {
          map.setView(allLatLngs[0], 14)
        } else {
          map.fitBounds(L.latLngBounds(allLatLngs).pad(0.18))
        }

        setTimeout(() => map.invalidateSize(), 80)
      })
      .catch(() => {
        /* ignore */
      })

    return () => {
      cancelled = true
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove()
        mapInstanceRef.current = null
      }
    }
  }, [valid, trail, hasGpsTrail, roadRoute, mapHostId])

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
      {/* Route & Road Information Card Overlay */}
      {(activeRouteUsed || activeRoadNames.length > 0 || activeDistanceKm != null || routeLoading) && (
        <div className='absolute top-3 left-3 right-3 sm:right-auto sm:max-w-md z-[500] bg-white/95 backdrop-blur-sm border border-blue-200/80 rounded-xl p-3 shadow-md transition-all'>
          <div className='flex items-start justify-between gap-2'>
            <div className='min-w-0'>
              <div className='flex items-center gap-1.5'>
                <span className='inline-flex items-center justify-center w-5 h-5 rounded-full bg-blue-100 text-blue-700 text-xs font-bold'>
                  🛣️
                </span>
                <span className='text-xs font-semibold uppercase tracking-wider text-blue-900'>
                  Route Used
                </span>
                {routeLoading ? (
                  <span className='text-[10px] text-blue-600 animate-pulse font-medium'>
                    · Calculating road path…
                  </span>
                ) : (
                  <span className='text-[10px] bg-emerald-100 text-emerald-800 font-semibold px-1.5 py-0.2 rounded'>
                    Road matched
                  </span>
                )}
              </div>
              <p className='text-sm font-bold text-gray-900 mt-1 line-clamp-2'>
                {activeRouteUsed || (activeRoadNames.length ? `Via ${activeRoadNames.slice(0, 3).join(', ')}` : 'Traveled road path')}
              </p>
            </div>
            {activeDistanceKm != null && activeDistanceKm > 0 ? (
              <div className='text-right shrink-0 pl-2'>
                <span className='text-base font-extrabold text-blue-700 tabular-nums'>
                  {activeDistanceKm} km
                </span>
                <p className='text-[10px] text-gray-500 font-medium'>road distance</p>
              </div>
            ) : null}
          </div>

          {activeRoadNames.length > 0 && (
            <div className='mt-2 pt-2 border-t border-gray-100 flex flex-wrap items-center gap-1.5'>
              <span className='text-[11px] font-medium text-gray-500'>Roads:</span>
              {activeRoadNames.slice(0, 5).map((road, idx) => (
                <span
                  key={`${road}-${idx}`}
                  className='text-[11px] font-medium bg-slate-100 text-slate-800 px-2 py-0.5 rounded-md border border-slate-200'
                >
                  {road}
                </span>
              ))}
              {activeRoadNames.length > 5 && (
                <span className='text-[10px] text-gray-400 font-medium'>
                  +{activeRoadNames.length - 5} more
                </span>
              )}
            </div>
          )}
        </div>
      )}

      {/* Leaflet Map Container */}
      <div
        id={`travel-route-map-${mapHostId}`}
        ref={mapRef}
        className='w-full z-0'
        style={{ height }}
      />

      {/* Map Action Buttons */}
      <div className='absolute bottom-3 right-3 z-[500] flex flex-wrap gap-2'>
        {routeUrl ? (
          <a
            href={routeUrl}
            target='_blank'
            rel='noopener noreferrer'
            className='rounded-lg bg-white/95 border border-gray-200 px-3 py-1.5 text-xs font-semibold text-indigo-700 shadow-sm hover:bg-white flex items-center gap-1.5'
          >
            <svg className='w-3.5 h-3.5 text-indigo-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'>
              <path strokeLinecap='round' strokeLinejoin='round' strokeWidth='2' d='M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14' />
            </svg>
            <span>Open in Google Maps</span>
          </a>
        ) : null}
      </div>

      {/* Footer Info Strip */}
      <div className='px-4 py-2 text-[11px] text-gray-600 border-t border-gray-100 bg-slate-50/80 flex flex-wrap items-center justify-between gap-2'>
        <div className='flex items-center gap-2'>
          <span className='w-2.5 h-2.5 rounded-full bg-blue-600 inline-block'></span>
          <span>
            {roadRoute?.roadCoordinates?.length
              ? 'Blue line shows the actual driving road paths traveled across all visited stops.'
              : hasGpsTrail
                ? 'Blue line shows your continuous GPS path.'
                : 'Road path will update with the driving route and roads used.'}
          </span>
        </div>
        <span className='text-[10px] text-gray-400'>
          Calculated by road routing · Not shortest Euclidean path
        </span>
      </div>
    </div>
  )
}

export default TravelRouteMap
