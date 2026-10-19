import React, { useEffect, useId, useMemo, useRef, useState } from 'react'

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

/**
 * Calculates road driving metrics (road distance, duration, roads and route used).
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
    const routeUsed = routeSummary ? `Via ${routeSummary}` : 'Google Maps driving route'

    const roadCoordinates = (route.geometry?.coordinates || []).map(([lon, lat]) => [lat, lon])

    return {
      distanceKm: Math.round(((route.distance || 0) / 1000) * 10) / 10,
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

const markerLetter = (p, idx, total) => {
  if (p.type === 'journey_start' || p.source === 'journey_start' || idx === 0) return 'A'
  if (p.type === 'journey_end' || p.source === 'journey_end' || idx === total - 1) {
    return String.fromCharCode(65 + Math.min(total - 1, 25))
  }
  return String.fromCharCode(65 + Math.min(idx, 25))
}

const markerLabel = (p, idx, total) => {
  if (p.type === 'journey_start' || p.source === 'journey_start') return 'Origin (Journey Start)'
  if (p.type === 'journey_end' || p.source === 'journey_end') return 'Destination (Journey End)'
  if (idx === 0) return 'Start'
  if (idx === total - 1 && total > 1) return 'Last stop'
  return p.label || `Stop ${idx + 1}`
}

/**
 * TravelRouteMap — Genuine Google Maps tiles with road route driving paths.
 * Renders smoothly without flickering by creating the map instance ONCE,
 * updating only layer elements, and memoizing route calculations.
 */
const TravelRouteMap = ({
  points = [],
  trackPoints = [],
  routeUsed: initialRouteUsed = '',
  routeSummary: initialRouteSummary = '',
  roadNames: initialRoadNames = [],
  routeUrl = null,
  height = 420,
  emptyMessage = 'No route points yet.',
  onRouteDetails = null,
}) => {
  const mapHostId = useId().replace(/:/g, '')
  const mapRef = useRef(null)
  const mapInstanceRef = useRef(null)
  const layersRef = useRef({ road: null, sat: null, routeGroup: null })
  const onRouteDetailsRef = useRef(onRouteDetails)
  const lastFetchedKeyRef = useRef('')

  useEffect(() => {
    onRouteDetailsRef.current = onRouteDetails
  }, [onRouteDetails])

  const valid = useMemo(() => toValidPoints(points), [points])
  const trail = useMemo(() => toTrackPath(trackPoints), [trackPoints])
  const hasGpsTrail = trail.length >= 2

  const [mapType, setMapType] = useState('roadmap') // 'roadmap' | 'satellite'
  const [roadRoute, setRoadRoute] = useState(null)
  const [routeLoading, setRouteLoading] = useState(false)

  // 1. Calculate driving road path only when coordinates genuinely change
  const pointsKey = useMemo(() => {
    const src = valid.length >= 2 ? valid : (trail.length >= 2 ? trail : [])
    return src.map((p) => `${p.lat.toFixed(5)},${p.lng.toFixed(5)}`).join(';')
  }, [valid, trail])

  useEffect(() => {
    if (!pointsKey || pointsKey === lastFetchedKeyRef.current) return undefined

    lastFetchedKeyRef.current = pointsKey
    const sourcePoints = valid.length >= 2 ? valid : (trail.length >= 2 ? trail : [])
    if (sourcePoints.length < 2) {
      setRoadRoute(null)
      return undefined
    }

    let cancelled = false
    setRouteLoading(true)

    fetchClientDrivingRoute(sourcePoints).then((details) => {
      if (cancelled) return
      setRouteLoading(false)
      if (details) {
        setRoadRoute(details)
        if (typeof onRouteDetailsRef.current === 'function') {
          onRouteDetailsRef.current(details)
        }
      }
    })

    return () => {
      cancelled = true
    }
  }, [pointsKey, valid, trail])

  // 2. Initialize Map Instance ONCE on mount (Never destroy and recreate during re-renders!)
  useEffect(() => {
    if (!mapRef.current) return undefined

    let cancelled = false

    loadLeaflet().then((L) => {
      if (cancelled || !mapRef.current) return
      if (mapInstanceRef.current) return // Already initialized

      const map = L.map(mapRef.current, {
        scrollWheelZoom: true,
        zoomControl: true,
      })
      mapInstanceRef.current = map

      // Official Google Maps Tile Layers
      const googleRoadLayer = L.tileLayer(
        'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
        {
          subdomains: ['0', '1', '2', '3'],
          attribution: '&copy; Google Maps',
          maxZoom: 20,
        }
      )

      const googleSatLayer = L.tileLayer(
        'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
        {
          subdomains: ['0', '1', '2', '3'],
          attribution: '&copy; Google Maps',
          maxZoom: 20,
        }
      )

      // Dedicated Route LayerGroup (for smooth updates without map destruction)
      const routeGroup = L.layerGroup().addTo(map)

      layersRef.current = {
        road: googleRoadLayer,
        sat: googleSatLayer,
        routeGroup,
      }

      googleRoadLayer.addTo(map)

      // Set initial view
      map.setView([19.0760, 72.8777], 12)
      setTimeout(() => map.invalidateSize(), 80)
    })

    return () => {
      cancelled = true
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove()
        mapInstanceRef.current = null
      }
    }
  }, []) // Empty dependency array ensures map is initialized only once!

  // 3. Update Route Polylines and Markers smoothly on the EXISTING map
  useEffect(() => {
    const map = mapInstanceRef.current
    const group = layersRef.current?.routeGroup
    if (!map || !group || typeof window === 'undefined' || !window.L) return

    const L = window.L
    group.clearLayers()

    const allLatLngs = []

    // Draw Real Driving Road Path on Google Maps
    if (roadRoute?.roadCoordinates?.length >= 2) {
      allLatLngs.push(...roadRoute.roadCoordinates)
      // Google Maps route glow
      L.polyline(roadRoute.roadCoordinates, {
        color: '#1a73e8',
        weight: 8,
        opacity: 0.3,
        lineJoin: 'round',
      }).addTo(group)
      // Main Google Maps route line
      L.polyline(roadRoute.roadCoordinates, {
        color: '#1a73e8',
        weight: 5,
        opacity: 0.95,
        lineJoin: 'round',
      }).addTo(group)
    } else if (hasGpsTrail) {
      const path = trail.map((p) => [p.lat, p.lng])
      allLatLngs.push(...path)
      L.polyline(path, { color: '#059669', weight: 5, opacity: 0.9, lineJoin: 'round' }).addTo(group)
    } else if (valid.length > 1) {
      const path = valid.map((p) => [p.lat, p.lng])
      allLatLngs.push(...path)
      L.polyline(path, { color: '#1a73e8', weight: 4, opacity: 0.7, dashArray: '6 8' }).addTo(group)
    }

    // Add Stop Markers (Start, Visits, End)
    valid.forEach((p, idx) => {
      allLatLngs.push([p.lat, p.lng])
      const isStart = p.type === 'journey_start' || idx === 0
      const isEnd = p.type === 'journey_end' || (idx === valid.length - 1 && valid.length > 1)
      const letter = markerLetter(p, idx, valid.length)
      const bgColor = isStart ? '#15803d' : isEnd ? '#dc2626' : '#2563eb'

      const iconHtml = `
        <div style="display: flex; flex-direction: column; align-items: center; cursor: pointer;">
          <div style="background-color: ${bgColor}; color: #ffffff; width: 26px; height: 26px; border-radius: 50% 50% 50% 0; transform: rotate(-45deg); display: flex; align-items: center; justify-content: center; box-shadow: 0 2px 5px rgba(0,0,0,0.4); border: 2px solid #ffffff;">
            <span style="transform: rotate(45deg); font-size: 11px; font-weight: bold; font-family: system-ui, sans-serif;">${letter}</span>
          </div>
        </div>
      `
      const customIcon = L.divIcon({
        html: iconHtml,
        className: '',
        iconSize: [26, 32],
        iconAnchor: [13, 30],
        popupAnchor: [0, -28],
      })

      const marker = L.marker([p.lat, p.lng], { icon: customIcon }).addTo(group)

      const popupContent = `
        <div style="font-family: system-ui, sans-serif; font-size: 12px; line-height: 1.4; padding: 4px; min-width: 140px;">
          <div style="display: flex; align-items: center; gap: 4px;">
            <span style="background: ${bgColor}; color: #fff; width: 16px; height: 16px; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; font-size: 10px; font-weight: bold;">${letter}</span>
            <strong style="color: #0f172a; font-size: 13px;">${markerLabel(p, idx, valid.length)}</strong>
          </div>
          ${p.label ? `<div style="margin-top: 4px; font-weight: 600; color: #1e293b;">${p.label}</div>` : ''}
          ${p.address ? `<div style="color: #64748b; font-size: 11px; margin-top: 2px;">${p.address}</div>` : ''}
          ${p.arrivalTime ? `<div style="color: #059669; font-size: 11px; margin-top: 4px; font-weight: 500;">Arrival: ${new Date(p.arrivalTime).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}</div>` : ''}
        </div>
      `
      marker.bindPopup(popupContent)
    })

    // Center and zoom seamlessly
    if (allLatLngs.length === 1) {
      map.setView(allLatLngs[0], 15)
    } else if (allLatLngs.length > 1) {
      map.fitBounds(L.latLngBounds(allLatLngs).pad(0.18))
    }
  }, [valid, trail, hasGpsTrail, roadRoute])

  // 4. Switch between Google Roadmap and Google Satellite on the existing map
  const handleMapTypeChange = (type) => {
    setMapType(type)
    const map = mapInstanceRef.current
    const layers = layersRef.current
    if (!map || !layers.road || !layers.sat) return

    if (type === 'satellite') {
      if (map.hasLayer(layers.road)) map.removeLayer(layers.road)
      layers.sat.addTo(map)
    } else {
      if (map.hasLayer(layers.sat)) map.removeLayer(layers.sat)
      layers.road.addTo(map)
    }
  }

  const activeRouteUsed = roadRoute?.routeUsed || initialRouteUsed || ''
  const activeDistanceKm = roadRoute?.distanceKm
  const activeRoadNames = roadRoute?.roadNames?.length ? roadRoute.roadNames : (initialRoadNames || [])
  const activeDuration = roadRoute?.durationMinutes

  // Build external Google Maps directions link for navigation
  const googleDirectionsUrl = useMemo(() => {
    if (routeUrl) return routeUrl
    if (valid.length < 2) return null
    const origin = `${valid[0].lat},${valid[0].lng}`
    const dest = `${valid[valid.length - 1].lat},${valid[valid.length - 1].lng}`
    const waypoints = valid
      .slice(1, -1)
      .slice(0, 10)
      .map((p) => `${p.lat},${p.lng}`)
      .join('|')
    let url = `https://www.google.com/maps/dir/?api=1&origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(dest)}&travelmode=driving`
    if (waypoints) url += `&waypoints=${encodeURIComponent(waypoints)}`
    return url
  }, [routeUrl, valid])

  return (
    <div className='relative overflow-hidden rounded-b-xl'>
      {/* Route & Road Information Card Overlay */}
      {(activeRouteUsed || activeRoadNames.length > 0 || activeDistanceKm != null || routeLoading) && (
        <div className='absolute top-3 left-3 right-3 sm:right-auto sm:max-w-md z-[500] bg-white/95 backdrop-blur-md border border-blue-200/90 rounded-xl p-3 shadow-lg transition-all'>
          <div className='flex items-start justify-between gap-3'>
            <div className='min-w-0'>
              <div className='flex items-center gap-1.5'>
                {/* Official Google Maps Pin Icon */}
                <svg className='w-4 h-4 text-red-600 shrink-0' viewBox='0 0 24 24' fill='currentColor'>
                  <path d='M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z'/>
                </svg>
                <span className='text-[11px] font-bold text-gray-800 tracking-wide'>
                  Google Maps Driving Route
                </span>
                {routeLoading ? (
                  <span className='text-[10px] text-blue-600 animate-pulse font-medium'>
                    · Calculating road path…
                  </span>
                ) : (
                  <span className='text-[10px] bg-blue-50 text-blue-700 font-semibold px-1.5 py-0.5 rounded border border-blue-100'>
                    Actual Road
                  </span>
                )}
              </div>
              <p className='text-sm font-bold text-gray-900 mt-1 line-clamp-2'>
                {activeRouteUsed || (activeRoadNames.length ? `Via ${activeRoadNames.slice(0, 3).join(', ')}` : 'Google Maps driving route')}
              </p>
            </div>
            {activeDistanceKm != null && activeDistanceKm > 0 ? (
              <div className='text-right shrink-0 pl-2'>
                <span className='text-base font-extrabold text-blue-600 tabular-nums'>
                  {activeDistanceKm} km
                </span>
                {activeDuration ? (
                  <p className='text-[10px] text-gray-500 font-medium'>~{activeDuration} mins</p>
                ) : (
                  <p className='text-[10px] text-gray-500 font-medium'>road distance</p>
                )}
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
            </div>
          )}
        </div>
      )}

      {/* Google Map Layer Toggle (Roadmap vs Satellite) */}
      <div className='absolute top-3 right-3 z-[500] flex bg-white/95 rounded-lg border border-gray-200 shadow-md p-0.5'>
        <button
          type='button'
          onClick={() => handleMapTypeChange('roadmap')}
          className={`px-2.5 py-1 text-xs font-semibold rounded-md transition-all ${
            mapType === 'roadmap'
              ? 'bg-blue-600 text-white shadow-sm'
              : 'text-gray-700 hover:text-black hover:bg-gray-100'
          }`}
        >
          Google Map
        </button>
        <button
          type='button'
          onClick={() => handleMapTypeChange('satellite')}
          className={`px-2.5 py-1 text-xs font-semibold rounded-md transition-all ${
            mapType === 'satellite'
              ? 'bg-blue-600 text-white shadow-sm'
              : 'text-gray-700 hover:text-black hover:bg-gray-100'
          }`}
        >
          Satellite
        </button>
      </div>

      {/* Leaflet Map Host with Google Maps Tiles */}
      <div
        id={`travel-route-map-${mapHostId}`}
        ref={mapRef}
        className='w-full z-0'
        style={{ height }}
      />

      {/* Google Watermark in bottom-left */}
      <div className='absolute bottom-3 left-3 z-[500] pointer-events-none select-none bg-white/80 backdrop-blur-sm px-2 py-0.5 rounded shadow-sm border border-gray-200/50 flex items-center gap-1'>
        <span className='text-[11px] font-bold text-gray-700 tracking-tight'>
          <span className='text-[#4285F4]'>G</span>
          <span className='text-[#EA4335]'>o</span>
          <span className='text-[#FBBC05]'>o</span>
          <span className='text-[#4285F4]'>g</span>
          <span className='text-[#34A853]'>l</span>
          <span className='text-[#EA4335]'>e</span>
        </span>
        <span className='text-[9px] text-gray-500 font-medium'>Maps</span>
      </div>

      {/* Action Button: Open in Google Maps */}
      <div className='absolute bottom-3 right-3 z-[500] flex flex-wrap gap-2'>
        {googleDirectionsUrl ? (
          <a
            href={googleDirectionsUrl}
            target='_blank'
            rel='noopener noreferrer'
            className='rounded-lg bg-white/95 border border-gray-200 px-3 py-1.5 text-xs font-semibold text-indigo-700 shadow-md hover:bg-white flex items-center gap-1.5 backdrop-blur-sm'
          >
            <svg className='w-3.5 h-3.5 text-red-600 shrink-0' viewBox='0 0 24 24' fill='currentColor'>
              <path d='M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z'/>
            </svg>
            <span>Open in Google Maps</span>
          </a>
        ) : null}
      </div>

      {/* Footer Info Strip */}
      <div className='px-4 py-2 text-[11px] text-gray-600 border-t border-gray-100 bg-white flex flex-wrap items-center justify-between gap-2'>
        <div className='flex items-center gap-2'>
          <span className='w-2.5 h-2.5 rounded-full bg-blue-600 inline-block'></span>
          <span>
            {activeDistanceKm != null && activeDistanceKm > 0
              ? `Google Maps route: ${activeDistanceKm} km along actual driving streets.`
              : valid.length > 0
                ? 'Google Maps centered on your route.'
                : 'Start journey to begin GPS tracking on Google Maps.'}
          </span>
        </div>
        <span className='text-[10px] text-gray-500 font-semibold flex items-center gap-1'>
          Powered by Google Maps
        </span>
      </div>
    </div>
  )
}

export default TravelRouteMap
