import React, { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../api/axios'
import {
  formatINR,
  LISTING_TYPES,
  PROPERTY_CATEGORIES,
  PROPERTY_STATUSES,
  PROPERTY_TYPES,
  STATUS_STYLES,
} from '../../config/propertyListing'

const PropertyListingsView = () => {
  const navigate = useNavigate()
  const [properties, setProperties] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState('')
  const [listingType, setListingType] = useState('')
  const [propertyType, setPropertyType] = useState('')
  const [propertyCategory, setPropertyCategory] = useState('')
  const [viewProperty, setViewProperty] = useState(null)

  const fetchProperties = async () => {
    try {
      setLoading(true)
      setError(null)
      const res = await api.get('/properties')
      setProperties(Array.isArray(res.data) ? res.data : [])
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error fetching properties')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchProperties()
  }, [])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return properties.filter((p) => {
      if (status && p.status !== status) return false
      if (listingType && p.listingType !== listingType) return false
      if (propertyType && p.propertyType !== propertyType) return false
      if (propertyCategory && p.propertyCategory !== propertyCategory) return false
      if (!q) return true
      const haystack = [
        p.title,
        p.propertyCode,
        p.locality,
        p.subLocality,
        p.city,
        p.district,
        p.village,
        p.surveyNumber,
        p.address,
        p.ownerName,
        p.ownerPhone,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase()
      return haystack.includes(q)
    })
  }, [properties, search, status, listingType, propertyType, propertyCategory])

  const stats = useMemo(() => ({
    total: properties.length,
    available: properties.filter((p) => p.status === 'Available').length,
    sale: properties.filter((p) => p.listingType === 'Sale').length,
    rent: properties.filter((p) => p.listingType === 'Rent' || p.listingType === 'Lease').length,
  }), [properties])

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this property listing?')) return
    try {
      await api.delete(`/properties/${id}`)
      fetchProperties()
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error deleting property')
    }
  }

  const locationLabel = (p) =>
    [p.locality, p.city, p.state].filter(Boolean).join(', ') || p.address || '—'

  return (
    <div className='p-6 md:p-8 w-full bg-[#f4f6f9] min-h-full space-y-5'>
      <div className='flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>Property Listing</h1>
          <p className='text-sm text-gray-500 mt-1'>List and manage all property inventory details</p>
        </div>
        <button
          type='button'
          onClick={() => navigate('/add-property')}
          className='inline-flex items-center justify-center rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700'
        >
          + Add Property
        </button>
      </div>

      <div className='grid grid-cols-2 lg:grid-cols-4 gap-3'>
        {[
          { label: 'Total Listings', value: stats.total },
          { label: 'Available', value: stats.available },
          { label: 'For Sale', value: stats.sale },
          { label: 'For Rent / Lease', value: stats.rent },
        ].map((card) => (
          <div key={card.label} className='bg-white rounded-xl border border-gray-100 shadow-sm p-4'>
            <p className='text-xs text-gray-500 font-medium'>{card.label}</p>
            <p className='text-2xl font-bold text-gray-900 mt-1'>{card.value}</p>
          </div>
        ))}
      </div>

      <div className='bg-white rounded-xl border border-gray-100 shadow-sm'>
        <div className='flex flex-col lg:flex-row gap-3 p-4 border-b border-gray-100'>
          <input
            type='text'
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder='Search title, code, locality, city, owner...'
            className='flex-1 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
          />
          <select value={status} onChange={(e) => setStatus(e.target.value)} className='rounded-lg border border-gray-300 px-3 py-2 text-sm'>
            <option value=''>All Statuses</option>
            {PROPERTY_STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
          <select value={listingType} onChange={(e) => setListingType(e.target.value)} className='rounded-lg border border-gray-300 px-3 py-2 text-sm'>
            <option value=''>All Listing Types</option>
            {LISTING_TYPES.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
          <select value={propertyType} onChange={(e) => setPropertyType(e.target.value)} className='rounded-lg border border-gray-300 px-3 py-2 text-sm'>
            <option value=''>All Property Types</option>
            {PROPERTY_TYPES.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
          <select value={propertyCategory} onChange={(e) => setPropertyCategory(e.target.value)} className='rounded-lg border border-gray-300 px-3 py-2 text-sm'>
            <option value=''>All Categories</option>
            {PROPERTY_CATEGORIES.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
        </div>

        {error && (
          <div className='mx-4 mt-4 rounded-lg bg-red-50 border border-red-100 px-3 py-2'>
            <p className='text-red-600 text-sm'>{error}</p>
          </div>
        )}

        {loading ? (
          <p className='p-8 text-sm text-gray-500 text-center'>Loading properties…</p>
        ) : (
          <div className='overflow-x-auto'>
            <table className='min-w-full text-sm'>
              <thead>
                <tr className='text-left text-xs text-gray-500 uppercase tracking-wide border-b border-gray-100 bg-gray-50'>
                  <th className='px-4 py-3 font-medium'>Property</th>
                  <th className='px-4 py-3 font-medium'>Category</th>
                  <th className='px-4 py-3 font-medium'>Type</th>
                  <th className='px-4 py-3 font-medium'>Listing</th>
                  <th className='px-4 py-3 font-medium'>Location</th>
                  <th className='px-4 py-3 font-medium'>Price</th>
                  <th className='px-4 py-3 font-medium'>Specs</th>
                  <th className='px-4 py-3 font-medium'>Status</th>
                  <th className='px-4 py-3 font-medium'>Actions</th>
                </tr>
              </thead>
              <tbody className='divide-y divide-gray-50'>
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={9} className='px-4 py-12 text-center text-gray-500'>
                      No property listings found. Add your first property to get started.
                    </td>
                  </tr>
                ) : (
                  filtered.map((p) => (
                    <tr key={p._id} className='hover:bg-gray-50/70'>
                      <td className='px-4 py-3'>
                        <p className='font-medium text-gray-900'>{p.title}</p>
                        <p className='text-xs text-gray-400'>{p.propertyCode || 'No code'}</p>
                      </td>
                      <td className='px-4 py-3 text-gray-700'>{p.propertyCategory || '—'}</td>
                      <td className='px-4 py-3 text-gray-700'>{p.propertyType}</td>
                      <td className='px-4 py-3 text-gray-700'>{p.listingType}</td>
                      <td className='px-4 py-3 text-gray-600 max-w-[180px] truncate' title={locationLabel(p)}>
                        {locationLabel(p)}
                      </td>
                      <td className='px-4 py-3 font-medium text-gray-900 whitespace-nowrap'>
                        {formatINR(p.price)}
                        {p.priceUnit && p.priceUnit !== 'Total' ? (
                          <span className='text-xs text-gray-400 font-normal'> / {p.priceUnit.replace('Per ', '')}</span>
                        ) : null}
                      </td>
                      <td className='px-4 py-3 text-gray-600 whitespace-nowrap'>
                        {[
                          p.bedrooms != null ? `${p.bedrooms} BHK` : null,
                          p.builtUpArea != null ? `${p.builtUpArea} ${p.areaUnit || 'sqft'}` : null,
                        ].filter(Boolean).join(' · ') || '—'}
                      </td>
                      <td className='px-4 py-3'>
                        <span className={`inline-flex rounded-full border px-2.5 py-1 text-xs font-medium ${STATUS_STYLES[p.status] || STATUS_STYLES['Off Market']}`}>
                          {p.status}
                        </span>
                      </td>
                      <td className='px-4 py-3'>
                        <div className='flex items-center gap-2'>
                          <button type='button' onClick={() => setViewProperty(p)} className='text-xs font-medium text-gray-600 hover:text-gray-900'>View</button>
                          <button type='button' onClick={() => navigate(`/schedule-site-visit?propertyId=${p._id}`)} className='text-xs font-medium text-emerald-600 hover:text-emerald-700'>Visit</button>
                          <button type='button' onClick={() => navigate(`/properties/edit/${p._id}`)} className='text-xs font-medium text-blue-600 hover:text-blue-700'>Edit</button>
                          <button type='button' onClick={() => handleDelete(p._id)} className='text-xs font-medium text-red-600 hover:text-red-700'>Delete</button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {viewProperty && (
        <div className='fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50' role='dialog' aria-modal='true'>
          <div className='bg-white rounded-xl shadow-xl max-w-2xl w-full p-5 max-h-[90vh] overflow-y-auto'>
            <div className='flex items-start justify-between gap-3 mb-4'>
              <div>
                <h2 className='text-lg font-semibold text-gray-900'>{viewProperty.title}</h2>
                <p className='text-sm text-gray-500'>{viewProperty.propertyCode || 'No property code'}</p>
              </div>
              <button type='button' onClick={() => setViewProperty(null)} className='text-gray-400 hover:text-gray-600 text-xl leading-none'>&times;</button>
            </div>
            <div className='grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm'>
              {[
                ['Category', viewProperty.propertyCategory],
                ['Type', viewProperty.propertyType],
                ['Development', viewProperty.developmentStatus],
                ['Source', viewProperty.source],
                ['Listing', viewProperty.listingType],
                ['Status', viewProperty.status],
                ['Price', `${formatINR(viewProperty.price)}${viewProperty.priceUnit && viewProperty.priceUnit !== 'Total' ? ` (${viewProperty.priceUnit})` : ''}`],
                ['Expected Price', formatINR(viewProperty.expectedPrice)],
                ['Price / Sqft', formatINR(viewProperty.pricePerSqft)],
                ['Booking Amount', formatINR(viewProperty.bookingAmount)],
                ['Brokerage', formatINR(viewProperty.brokerage)],
                ['GST', viewProperty.gstApplicable ? 'Yes' : 'No'],
                ['Negotiable', viewProperty.negotiable ? 'Yes' : 'No'],
                ['Built-up', viewProperty.builtUpArea != null ? `${viewProperty.builtUpArea} ${viewProperty.areaUnit}` : '—'],
                ['Carpet', viewProperty.carpetArea != null ? `${viewProperty.carpetArea} ${viewProperty.areaUnit}` : '—'],
                ['Bedrooms', viewProperty.bedrooms ?? '—'],
                ['Bathrooms', viewProperty.bathrooms ?? '—'],
                ['Parking', [viewProperty.parking, viewProperty.parkingType].filter(Boolean).join(' · ') || '—'],
                ['Furnished', viewProperty.furnishedStatus],
                ['Floor', [viewProperty.floor, viewProperty.totalFloors != null ? `of ${viewProperty.totalFloors}` : null].filter(Boolean).join(' ') || '—'],
                ['Facing', viewProperty.facing || '—'],
                ['RERA', viewProperty.reraNumber || '—'],
                ['Owner', viewProperty.ownerName || '—'],
                ['Owner Phone', viewProperty.ownerPhone || '—'],
                ['Location', locationLabel(viewProperty)],
                ['District', viewProperty.district || '—'],
                ['Country', viewProperty.country || '—'],
                ['Lat / Long', [viewProperty.latitude, viewProperty.longitude].filter((v) => v != null).join(', ') || '—'],
                ['Survey No.', viewProperty.surveyNumber || '—'],
                ['Gat No.', viewProperty.gatNumber || '—'],
                ['Khasra No.', viewProperty.khasraNumber || '—'],
                ['Property Card', viewProperty.propertyCardNumber || '—'],
                ['Village', viewProperty.village || '—'],
                ['Taluka', viewProperty.taluka || '—'],
                ['Land Type', viewProperty.landType || '—'],
                ['Zoning', viewProperty.zoning || '—'],
                ['Verification', viewProperty.verificationStatus || '—'],
                ['Verified By', viewProperty.verifiedBy?.name || '—'],
              ].map(([label, value]) => (
                <div key={label}>
                  <span className='block text-xs font-medium text-gray-500'>{label}</span>
                  <p className='text-gray-900 mt-0.5'>{value}</p>
                </div>
              ))}
            </div>
            {viewProperty.googleMapLink && (
              <div className='mt-3 text-sm'>
                <span className='block text-xs font-medium text-gray-500'>Google Map</span>
                <a href={viewProperty.googleMapLink} target='_blank' rel='noreferrer' className='text-blue-600 hover:underline break-all'>
                  {viewProperty.googleMapLink}
                </a>
              </div>
            )}
            {viewProperty.remarks && (
              <div className='mt-3 text-sm'>
                <span className='block text-xs font-medium text-gray-500'>Remarks</span>
                <p className='text-gray-900 mt-0.5 whitespace-pre-wrap'>{viewProperty.remarks}</p>
              </div>
            )}
            {viewProperty.address && (
              <div className='mt-3 text-sm'>
                <span className='block text-xs font-medium text-gray-500'>Address</span>
                <p className='text-gray-900 mt-0.5'>{viewProperty.address}</p>
              </div>
            )}
            {viewProperty.description && (
              <div className='mt-3 text-sm'>
                <span className='block text-xs font-medium text-gray-500'>Description</span>
                <p className='text-gray-900 mt-0.5 whitespace-pre-wrap'>{viewProperty.description}</p>
              </div>
            )}
            {viewProperty.amenities?.length > 0 && (
              <div className='mt-3 text-sm'>
                <span className='block text-xs font-medium text-gray-500 mb-1'>Amenities</span>
                <div className='flex flex-wrap gap-1.5'>
                  {viewProperty.amenities.map((a) => (
                    <span key={a} className='rounded-full bg-gray-100 px-2.5 py-1 text-xs text-gray-700'>{a}</span>
                  ))}
                </div>
              </div>
            )}
            <div className='flex gap-2 mt-5'>
              <button
                type='button'
                onClick={() => { setViewProperty(null); navigate(`/properties/edit/${viewProperty._id}`) }}
                className='flex-1 bg-blue-600 text-white py-2 rounded-lg text-sm font-medium hover:bg-blue-700'
              >
                Edit Listing
              </button>
              <button
                type='button'
                onClick={() => setViewProperty(null)}
                className='flex-1 border border-gray-300 py-2 rounded-lg text-sm font-medium hover:bg-gray-50'
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default PropertyListingsView
