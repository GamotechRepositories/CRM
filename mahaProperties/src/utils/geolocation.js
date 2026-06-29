const NOMINATIM_HEADERS = {
  Accept: 'application/json',
  'User-Agent': 'MultiCRM-Attendance/1.0',
}

export const buildAddressFromNominatim = (data) => {
  const a = data?.address || {}
  const parts = [
    a.house_number,
    a.building,
    a.road || a.pedestrian || a.footway,
    a.neighbourhood || a.suburb || a.quarter,
    a.village || a.city_district || a.district,
    a.city || a.town || a.municipality,
    a.state,
    a.postcode,
  ].filter(Boolean)

  if (parts.length > 0) return parts.join(', ')
  return String(data?.display_name || '').trim()
}

export const resolveAddressFromCoords = async (latitude, longitude) => {
  const lat = Number(latitude)
  const lon = Number(longitude)
  if (Number.isNaN(lat) || Number.isNaN(lon)) return ''

  try {
    const res = await fetch(
      `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=json&addressdetails=1&zoom=18`,
      { headers: NOMINATIM_HEADERS }
    )
    if (!res.ok) return ''
    const data = await res.json()
    return buildAddressFromNominatim(data)
  } catch {
    return ''
  }
}

export const formatCoords = (latitude, longitude) => {
  const lat = Number(latitude)
  const lon = Number(longitude)
  if (Number.isNaN(lat) || Number.isNaN(lon)) return ''
  return `${lat.toFixed(6)}, ${lon.toFixed(6)}`
}

export const getMapsUrl = (latitude, longitude) => {
  const lat = Number(latitude)
  const lon = Number(longitude)
  if (Number.isNaN(lat) || Number.isNaN(lon)) return null
  return `https://www.google.com/maps?q=${lat},${lon}`
}

export const getCurrentLocation = () =>
  new Promise((resolve) => {
    if (!navigator.geolocation) {
      resolve({ failed: true, reason: 'unsupported' })
      return
    }

    const onPosition = async (pos, done) => {
      const latitude = Number(pos.coords.latitude)
      const longitude = Number(pos.coords.longitude)
      if (Number.isNaN(latitude) || Number.isNaN(longitude)) {
        done({ failed: true, reason: 'unavailable' })
        return
      }
      const address = await resolveAddressFromCoords(latitude, longitude)
      done({
        latitude,
        longitude,
        address,
        accuracy: pos.coords.accuracy,
      })
    }

    const onError = (err, tryFallback) => {
      const reason =
        err?.code === 1 ? 'permission_denied' : err?.code === 3 ? 'timeout' : 'unavailable'
      if (tryFallback && reason !== 'permission_denied') {
        navigator.geolocation.getCurrentPosition(
          (pos) => onPosition(pos, resolve),
          () => resolve({ failed: true, reason }),
          { enableHighAccuracy: false, timeout: 12000, maximumAge: 60000 }
        )
        return
      }
      resolve({ failed: true, reason })
    }

    navigator.geolocation.getCurrentPosition(
      (pos) => onPosition(pos, resolve),
      (err) => onError(err, true),
      { enableHighAccuracy: true, timeout: 20000, maximumAge: 0 }
    )
  })

export const locationErrorMessage = (reason) => {
  if (reason === 'permission_denied') {
    return 'Location access denied. Allow location for this site in browser settings.'
  }
  if (reason === 'timeout') {
    return 'Location request timed out. Ensure device GPS/location is on.'
  }
  if (reason === 'unsupported') {
    return 'Your browser does not support location services.'
  }
  return 'Unable to detect current location. Enable GPS and try again.'
}
