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
