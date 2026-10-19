/** Earth-radius haversine distance in kilometres. */
export const haversineKm = (lat1, lon1, lat2, lon2) => {
  const toRad = (deg) => (Number(deg) * Math.PI) / 180;
  const a1 = toRad(lat1);
  const a2 = toRad(lat2);
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(a1) * Math.cos(a2) * Math.sin(dLon / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
};

export const roundKm = (km, digits = 2) => {
  const n = Number(km);
  if (!Number.isFinite(n)) return 0;
  const f = 10 ** digits;
  return Math.round(n * f) / f;
};

const toCoord = (point) => ({
  latitude: Number(point?.latitude ?? point?.lat),
  longitude: Number(point?.longitude ?? point?.lng ?? point?.lon),
});

/** Sum of haversine legs along a ordered path (actual GPS trail). */
export const pathDistanceKm = (points = []) => {
  const coords = (Array.isArray(points) ? points : [])
    .map(toCoord)
    .filter((p) => Number.isFinite(p.latitude) && Number.isFinite(p.longitude));
  if (coords.length < 2) return 0;
  let total = 0;
  for (let i = 1; i < coords.length; i += 1) {
    total += haversineKm(
      coords[i - 1].latitude,
      coords[i - 1].longitude,
      coords[i].latitude,
      coords[i].longitude
    );
  }
  return roundKm(total);
};

/** Total km along all GPS track points for a journey day. */
export const totalTrackedDistanceKm = (trackPoints = []) => {
  const sorted = (Array.isArray(trackPoints) ? trackPoints : [])
    .slice()
    .sort((a, b) => new Date(a.recordedAt) - new Date(b.recordedAt));
  return pathDistanceKm(sorted);
};

/**
 * Path km between two timestamps using GPS breadcrumbs (not straight-line).
 * When intermediate breadcrumbs are sparse, applies the 1.35x road curvature factor
 * rather than pure Euclidean displacement.
 */
export const pathDistanceBetweenTimes = (
  trackPoints = [],
  fromTime,
  toTime,
  fallbackFrom = null,
  fallbackTo = null
) => {
  const fromMs = new Date(fromTime).getTime();
  const toMs = new Date(toTime).getTime();
  if (!Number.isFinite(fromMs) || !Number.isFinite(toMs) || toMs <= fromMs) return 0;

  const mid = (Array.isArray(trackPoints) ? trackPoints : [])
    .filter((p) => {
      const t = new Date(p.recordedAt).getTime();
      return t >= fromMs && t <= toMs;
    })
    .sort((a, b) => new Date(a.recordedAt) - new Date(b.recordedAt))
    .map(toCoord);

  const chain = [];
  const from = toCoord(fallbackFrom);
  const to = toCoord(fallbackTo);
  if (Number.isFinite(from.latitude) && Number.isFinite(from.longitude)) chain.push(from);
  chain.push(...mid);
  if (Number.isFinite(to.latitude) && Number.isFinite(to.longitude)) {
    const last = chain[chain.length - 1];
    if (
      !last
      || last.latitude !== to.latitude
      || last.longitude !== to.longitude
    ) {
      chain.push(to);
    }
  }

  if (chain.length >= 2) {
    const raw = pathDistanceKm(chain);
    // If no intermediate breadcrumbs exist between from and to, apply the 1.35x road curvature factor
    return mid.length === 0 ? roundKm(raw * 1.35) : raw;
  }
  if (
    Number.isFinite(from.latitude)
    && Number.isFinite(from.longitude)
    && Number.isFinite(to.latitude)
    && Number.isFinite(to.longitude)
  ) {
    return roundKm(haversineKm(from.latitude, from.longitude, to.latitude, to.longitude) * 1.35);
  }
  return 0;
};

/**
 * Fetch real driving road route, geometry coordinates, distance, and road names using OSRM.
 * Falls back to dense GPS breadcrumbs or 1.35x road curvature factor if network/API fails.
 */
export const fetchRoadRoute = async (points = []) => {
  const coords = (Array.isArray(points) ? points : [])
    .map(toCoord)
    .filter((p) => Number.isFinite(p.latitude) && Number.isFinite(p.longitude));

  if (coords.length < 2) {
    return {
      distanceKm: 0,
      durationMinutes: 0,
      routeUsed: '',
      routeSummary: '',
      roadNames: [],
      coordinates: coords,
    };
  }

  let sampled = coords;
  if (coords.length > 25) {
    sampled = [coords[0]];
    const step = (coords.length - 2) / 23;
    for (let i = 1; i <= 23; i += 1) {
      sampled.push(coords[Math.round(i * step)]);
    }
    sampled.push(coords[coords.length - 1]);
  }

  const coordStr = sampled.map((c) => `${c.longitude},${c.latitude}`).join(';');
  const url = `https://router.project-osrm.org/route/v1/driving/${coordStr}?overview=full&geometries=geojson&steps=true`;

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 4000);
    const resp = await fetch(url, { signal: controller.signal });
    clearTimeout(timeout);

    if (resp.ok) {
      const data = await resp.json();
      const route = data?.routes?.[0];
      if (route) {
        const roadNamesSet = new Set();
        (route.legs || []).forEach((leg) => {
          (leg.steps || []).forEach((step) => {
            const name = String(step?.name || '').trim();
            if (name && !name.toLowerCase().startsWith('unnamed')) {
              roadNamesSet.add(name);
            }
          });
        });
        const roadNames = Array.from(roadNamesSet);
        const legSummaries = (route.legs || [])
          .map((l) => l.summary)
          .filter(Boolean)
          .join(', ');

        const routeSummary =
          legSummaries || (roadNames.length ? roadNames.slice(0, 3).join(', ') : 'Direct road route');
        const routeUsed = routeSummary ? `Via ${routeSummary}` : 'Driving road route';

        const rawCoords = route.geometry?.coordinates || [];
        const coordinates = rawCoords.map(([lon, lat]) => ({
          latitude: lat,
          longitude: lon,
        }));

        return {
          distanceKm: roundKm((route.distance || 0) / 1000),
          durationMinutes: Math.round((route.duration || 0) / 60),
          routeUsed,
          routeSummary,
          roadNames,
          coordinates: coordinates.length ? coordinates : coords,
        };
      }
    }
  } catch {
    /* Fallback to road curvature calculation */
  }

  let fallbackDistance = 0;
  if (coords.length >= 4) {
    fallbackDistance = pathDistanceKm(coords);
  } else {
    fallbackDistance = roundKm(pathDistanceKm(coords) * 1.35);
  }

  return {
    distanceKm: fallbackDistance,
    durationMinutes: Math.round(fallbackDistance * 2.5),
    routeUsed: 'Driving road route',
    routeSummary: 'Connecting road route',
    roadNames: [],
    coordinates: coords,
  };
};

/** Default reimbursement rate (INR per km). Override with TRAVEL_RATE_PER_KM. */
export const getTravelRatePerKm = () => {
  const fromEnv = Number(process.env.TRAVEL_RATE_PER_KM);
  return Number.isFinite(fromEnv) && fromEnv > 0 ? fromEnv : 12;
};

/**
 * Build a Google Maps directions URL for a sequence of points.
 * Opens in Maps as a multi-stop timeline/route.
 */
export const buildGoogleMapsDirectionsUrl = (points = []) => {
  const valid = (Array.isArray(points) ? points : [])
    .map((p) => ({
      lat: Number(p.latitude ?? p.lat),
      lng: Number(p.longitude ?? p.lng ?? p.lon),
    }))
    .filter((p) => Number.isFinite(p.lat) && Number.isFinite(p.lng));

  if (!valid.length) return null;
  if (valid.length === 1) {
    return `https://www.google.com/maps?q=${valid[0].lat},${valid[0].lng}`;
  }

  const origin = `${valid[0].lat},${valid[0].lng}`;
  const destination = `${valid[valid.length - 1].lat},${valid[valid.length - 1].lng}`;
  const waypoints = valid
    .slice(1, -1)
    .map((p) => `${p.lat},${p.lng}`)
    .join('|');

  let url = `https://www.google.com/maps/dir/?api=1&origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&travelmode=driving`;
  if (waypoints) url += `&waypoints=${encodeURIComponent(waypoints)}`;
  return url;
};
