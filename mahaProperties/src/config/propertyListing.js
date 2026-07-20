export const PROPERTY_TYPES = [
  'Apartment',
  'Villa',
  'Independent House',
  'Plot',
  'Commercial',
  'Office',
  'Shop',
  'Warehouse',
  'Farmhouse',
  'Other',
]

export const PROPERTY_CATEGORIES = [
  'Residential',
  'Commercial',
  'Industrial',
  'Agricultural',
]

export const DEVELOPMENT_STATUSES = [
  'Ready',
  'Under Construction',
  'New Launch',
  'Pre Launch',
  'Redevelopment',
]

export const PROPERTY_SOURCES = [
  'Owner',
  'Broker',
  'Builder',
  'Developer',
  'Internal',
]

export const PARKING_TYPES = [
  'None',
  'Open',
  'Covered',
  'Stilt',
  'Basement',
  'Stack',
]

export const VERIFICATION_STATUSES = [
  'Pending',
  'Verified',
  'Rejected',
  'Needs Review',
]

export const LAND_TYPES = [
  'Agricultural',
  'Non-Agricultural',
  'NA',
  'Industrial',
  'Residential',
  'Commercial',
  'Other',
]

export const LISTING_TYPES = ['Sale', 'Rent', 'Lease']

export const PROPERTY_STATUSES = [
  'Available',
  'Reserved',
  'Sold',
  'Rented',
  'Under Negotiation',
  'Off Market',
]

export const FURNISHED_STATUSES = [
  'Unfurnished',
  'Semi-Furnished',
  'Fully Furnished',
]

export const AREA_UNITS = ['sqft', 'sqm', 'acre', 'guntha']

export const PRICE_UNITS = ['Total', 'Per Sq Ft', 'Per Month']

export const STATUS_STYLES = {
  Available: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  Reserved: 'bg-amber-50 text-amber-700 border-amber-200',
  Sold: 'bg-blue-50 text-blue-700 border-blue-200',
  Rented: 'bg-indigo-50 text-indigo-700 border-indigo-200',
  'Under Negotiation': 'bg-purple-50 text-purple-700 border-purple-200',
  'Off Market': 'bg-gray-100 text-gray-600 border-gray-200',
}

export const formatINR = (num) => {
  if (num == null || num === '' || Number.isNaN(Number(num))) return '—'
  return `₹${Number(num).toLocaleString('en-IN', { maximumFractionDigits: 0 })}`
}

const numFields = [
  'price',
  'expectedPrice',
  'pricePerSqft',
  'bookingAmount',
  'brokerage',
  'maintenanceCharges',
  'securityDeposit',
  'builtUpArea',
  'carpetArea',
  'plotArea',
  'bedrooms',
  'bathrooms',
  'balconies',
  'parking',
  'totalFloors',
  'latitude',
  'longitude',
]

export const emptyPropertyForm = () => ({
  title: '',
  propertyCode: '',
  propertyType: 'Apartment',
  propertyCategory: 'Residential',
  developmentStatus: 'Ready',
  source: 'Owner',
  listingType: 'Sale',
  status: 'Available',
  price: '',
  expectedPrice: '',
  pricePerSqft: '',
  bookingAmount: '',
  brokerage: '',
  priceUnit: 'Total',
  gstApplicable: false,
  negotiable: true,
  maintenanceCharges: '',
  securityDeposit: '',
  builtUpArea: '',
  carpetArea: '',
  plotArea: '',
  areaUnit: 'sqft',
  bedrooms: '',
  bathrooms: '',
  balconies: '',
  parking: '',
  parkingType: 'None',
  floor: '',
  totalFloors: '',
  facing: '',
  furnishedStatus: 'Unfurnished',
  ageOfProperty: '',
  possessionDate: '',
  reraNumber: '',
  address: '',
  locality: '',
  subLocality: '',
  city: '',
  district: '',
  state: '',
  country: 'India',
  pincode: '',
  landmark: '',
  latitude: '',
  longitude: '',
  googleMapLink: '',
  surveyNumber: '',
  gatNumber: '',
  khasraNumber: '',
  propertyCardNumber: '',
  village: '',
  taluka: '',
  landType: '',
  zoning: '',
  verificationStatus: 'Pending',
  verifiedBy: '',
  verifiedDate: '',
  remarks: '',
  description: '',
  amenities: '',
  ownerName: '',
  ownerPhone: '',
  ownerEmail: '',
  imageUrls: '',
  notes: '',
})

export const propertyToForm = (p = {}) => ({
  ...emptyPropertyForm(),
  title: p.title || '',
  propertyCode: p.propertyCode || '',
  propertyType: p.propertyType || 'Apartment',
  propertyCategory: p.propertyCategory || 'Residential',
  developmentStatus: p.developmentStatus || 'Ready',
  source: p.source || 'Owner',
  listingType: p.listingType || 'Sale',
  status: p.status || 'Available',
  price: p.price ?? '',
  expectedPrice: p.expectedPrice ?? '',
  pricePerSqft: p.pricePerSqft ?? '',
  bookingAmount: p.bookingAmount ?? '',
  brokerage: p.brokerage ?? '',
  priceUnit: p.priceUnit || 'Total',
  gstApplicable: Boolean(p.gstApplicable),
  negotiable: p.negotiable !== false,
  maintenanceCharges: p.maintenanceCharges ?? '',
  securityDeposit: p.securityDeposit ?? '',
  builtUpArea: p.builtUpArea ?? '',
  carpetArea: p.carpetArea ?? '',
  plotArea: p.plotArea ?? '',
  areaUnit: p.areaUnit || 'sqft',
  bedrooms: p.bedrooms ?? '',
  bathrooms: p.bathrooms ?? '',
  balconies: p.balconies ?? '',
  parking: p.parking ?? '',
  parkingType: p.parkingType || 'None',
  floor: p.floor || '',
  totalFloors: p.totalFloors ?? '',
  facing: p.facing || '',
  furnishedStatus: p.furnishedStatus || 'Unfurnished',
  ageOfProperty: p.ageOfProperty || '',
  possessionDate: p.possessionDate ? String(p.possessionDate).slice(0, 10) : '',
  reraNumber: p.reraNumber || '',
  address: p.address || '',
  locality: p.locality || '',
  subLocality: p.subLocality || '',
  city: p.city || '',
  district: p.district || '',
  state: p.state || '',
  country: p.country || 'India',
  pincode: p.pincode || '',
  landmark: p.landmark || '',
  latitude: p.latitude ?? '',
  longitude: p.longitude ?? '',
  googleMapLink: p.googleMapLink || '',
  surveyNumber: p.surveyNumber || '',
  gatNumber: p.gatNumber || '',
  khasraNumber: p.khasraNumber || '',
  propertyCardNumber: p.propertyCardNumber || '',
  village: p.village || '',
  taluka: p.taluka || '',
  landType: p.landType || '',
  zoning: p.zoning || '',
  verificationStatus: p.verificationStatus || 'Pending',
  verifiedBy: p.verifiedBy?._id || p.verifiedBy || '',
  verifiedDate: p.verifiedDate ? String(p.verifiedDate).slice(0, 10) : '',
  remarks: p.remarks || '',
  description: p.description || '',
  amenities: Array.isArray(p.amenities) ? p.amenities.join(', ') : (p.amenities || ''),
  ownerName: p.ownerName || '',
  ownerPhone: p.ownerPhone || '',
  ownerEmail: p.ownerEmail || '',
  imageUrls: Array.isArray(p.imageUrls) ? p.imageUrls.join('\n') : (p.imageUrls || ''),
  notes: p.notes || '',
})

export const formToPayload = (form, listedBy) => {
  const payload = {
    ...form,
    gstApplicable: Boolean(form.gstApplicable),
    negotiable: Boolean(form.negotiable),
    possessionDate: form.possessionDate || null,
    verifiedDate: form.verifiedDate || null,
    verifiedBy: form.verifiedBy || null,
    amenities: form.amenities,
    imageUrls: form.imageUrls,
    listedBy: listedBy || null,
  }
  numFields.forEach((key) => {
    payload[key] = form[key] === '' || form[key] == null ? null : Number(form[key])
  })
  return payload
}
