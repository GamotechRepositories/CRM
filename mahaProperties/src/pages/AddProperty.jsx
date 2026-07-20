import React, { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import api from '../api/axios'
import { useAuth } from '../context/AuthContext'
import {
  AREA_UNITS,
  DEVELOPMENT_STATUSES,
  emptyPropertyForm,
  formToPayload,
  FURNISHED_STATUSES,
  LAND_TYPES,
  LISTING_TYPES,
  PARKING_TYPES,
  PRICE_UNITS,
  PROPERTY_CATEGORIES,
  PROPERTY_SOURCES,
  PROPERTY_STATUSES,
  PROPERTY_TYPES,
  propertyToForm,
  VERIFICATION_STATUSES,
} from '../config/propertyListing'

const Section = ({ title, children }) => (
  <div className='bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden'>
    <div className='px-5 py-3 border-b border-gray-100 bg-gray-50'>
      <h2 className='text-sm font-semibold text-gray-900'>{title}</h2>
    </div>
    <div className='p-5 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4'>{children}</div>
  </div>
)

const Field = ({ label, children, className = '' }) => (
  <div className={className}>
    <label className='block text-sm font-medium text-gray-700 mb-1'>{label}</label>
    {children}
  </div>
)

const AddProperty = () => {
  const { id } = useParams()
  const isEdit = Boolean(id)
  const navigate = useNavigate()
  const { user } = useAuth()
  const [form, setForm] = useState(emptyPropertyForm())
  const [employees, setEmployees] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  useEffect(() => {
    api.get('/employees').then((res) => {
      const list = Array.isArray(res.data) ? res.data : []
      setEmployees(list.filter((e) => e.status !== 'Inactive'))
    }).catch(() => setEmployees([]))
  }, [])

  useEffect(() => {
    if (!isEdit || !id) return
    api
      .get(`/properties/${id}`)
      .then((res) => setForm(propertyToForm(res.data)))
      .catch((err) => setError(err.response?.data?.message || 'Failed to load property'))
  }, [id, isEdit])

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target
    setForm((f) => ({ ...f, [name]: type === 'checkbox' ? checked : value }))
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!form.title?.trim()) {
      setError('Property title is required')
      return
    }
    setLoading(true)
    setError(null)
    try {
      const payload = formToPayload(form, user?._id)
      if (isEdit) {
        await api.put(`/properties/${id}`, payload)
      } else {
        await api.post('/properties', payload)
      }
      navigate('/properties')
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Error saving property')
    } finally {
      setLoading(false)
    }
  }

  const inputClass =
    'w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'

  return (
    <div className='p-6 md:p-8 w-full bg-[#f4f6f9] min-h-full'>
      <div className='flex items-center justify-between mb-6'>
        <div>
          <h1 className='text-2xl font-bold text-gray-900'>{isEdit ? 'Edit Property' : 'Add Property'}</h1>
          <p className='text-sm text-gray-500 mt-1'>Enter complete property listing details</p>
        </div>
        <button
          type='button'
          onClick={() => navigate('/properties')}
          className='rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-white'
        >
          Back to Listings
        </button>
      </div>

      {error && (
        <div className='mb-4 rounded-lg bg-red-50 border border-red-100 px-3 py-2'>
          <p className='text-red-600 text-sm'>{error}</p>
        </div>
      )}

      <form onSubmit={handleSubmit} className='space-y-5'>
        <Section title='Basic Details'>
          <Field label='Property Title *' className='sm:col-span-2 lg:col-span-2'>
            <input name='title' value={form.title} onChange={handleChange} required className={inputClass} placeholder='e.g. 3 BHK Apartment in Koregaon Park' />
          </Field>
          <Field label='Property Code'>
            <input name='propertyCode' value={form.propertyCode} onChange={handleChange} className={inputClass} placeholder='e.g. BP-APT-001' />
          </Field>
          <Field label='Property Category'>
            <select name='propertyCategory' value={form.propertyCategory} onChange={handleChange} className={inputClass}>
              {PROPERTY_CATEGORIES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
          <Field label='Property Type'>
            <select name='propertyType' value={form.propertyType} onChange={handleChange} className={inputClass}>
              {PROPERTY_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
          <Field label='Development Status'>
            <select name='developmentStatus' value={form.developmentStatus} onChange={handleChange} className={inputClass}>
              {DEVELOPMENT_STATUSES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
          <Field label='Source'>
            <select name='source' value={form.source} onChange={handleChange} className={inputClass}>
              {PROPERTY_SOURCES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
          <Field label='Listing Type'>
            <select name='listingType' value={form.listingType} onChange={handleChange} className={inputClass}>
              {LISTING_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
          <Field label='Status'>
            <select name='status' value={form.status} onChange={handleChange} className={inputClass}>
              {PROPERTY_STATUSES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
        </Section>

        <Section title='Pricing'>
          <Field label='Price'>
            <input name='price' type='number' min='0' value={form.price} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Expected Price'>
            <input name='expectedPrice' type='number' min='0' value={form.expectedPrice} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Price Per Sqft'>
            <input name='pricePerSqft' type='number' min='0' value={form.pricePerSqft} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Booking Amount'>
            <input name='bookingAmount' type='number' min='0' value={form.bookingAmount} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Brokerage'>
            <input name='brokerage' type='number' min='0' value={form.brokerage} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Price Unit'>
            <select name='priceUnit' value={form.priceUnit} onChange={handleChange} className={inputClass}>
              {PRICE_UNITS.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
          <Field label='Maintenance Charges'>
            <input name='maintenanceCharges' type='number' min='0' value={form.maintenanceCharges} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Security Deposit'>
            <input name='securityDeposit' type='number' min='0' value={form.securityDeposit} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Options' className='sm:col-span-2 lg:col-span-3'>
            <div className='flex flex-wrap gap-6 pt-2'>
              <label className='inline-flex items-center gap-2 text-sm text-gray-700'>
                <input type='checkbox' name='gstApplicable' checked={form.gstApplicable} onChange={handleChange} className='rounded border-gray-300' />
                GST Applicable
              </label>
              <label className='inline-flex items-center gap-2 text-sm text-gray-700'>
                <input type='checkbox' name='negotiable' checked={form.negotiable} onChange={handleChange} className='rounded border-gray-300' />
                Negotiable
              </label>
            </div>
          </Field>
        </Section>

        <Section title='Size & Specs'>
          <Field label='Built-up Area'>
            <input name='builtUpArea' type='number' min='0' value={form.builtUpArea} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Carpet Area'>
            <input name='carpetArea' type='number' min='0' value={form.carpetArea} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Plot Area'>
            <input name='plotArea' type='number' min='0' value={form.plotArea} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Area Unit'>
            <select name='areaUnit' value={form.areaUnit} onChange={handleChange} className={inputClass}>
              {AREA_UNITS.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
          <Field label='Bedrooms'>
            <input name='bedrooms' type='number' min='0' value={form.bedrooms} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Bathrooms'>
            <input name='bathrooms' type='number' min='0' value={form.bathrooms} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Balconies'>
            <input name='balconies' type='number' min='0' value={form.balconies} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Parking Count'>
            <input name='parking' type='number' min='0' value={form.parking} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Parking Type'>
            <select name='parkingType' value={form.parkingType} onChange={handleChange} className={inputClass}>
              {PARKING_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
          <Field label='Floor'>
            <input name='floor' value={form.floor} onChange={handleChange} className={inputClass} placeholder='e.g. 5 or Ground' />
          </Field>
          <Field label='Total Floors'>
            <input name='totalFloors' type='number' min='0' value={form.totalFloors} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Facing'>
            <input name='facing' value={form.facing} onChange={handleChange} className={inputClass} placeholder='e.g. East' />
          </Field>
          <Field label='Furnished Status'>
            <select name='furnishedStatus' value={form.furnishedStatus} onChange={handleChange} className={inputClass}>
              {FURNISHED_STATUSES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
          <Field label='Age of Property'>
            <input name='ageOfProperty' value={form.ageOfProperty} onChange={handleChange} className={inputClass} placeholder='e.g. 5 years' />
          </Field>
          <Field label='Possession Date'>
            <input name='possessionDate' type='date' value={form.possessionDate} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='RERA Number'>
            <input name='reraNumber' value={form.reraNumber} onChange={handleChange} className={inputClass} />
          </Field>
        </Section>

        <Section title='Location'>
          <Field label='Address' className='sm:col-span-2 lg:col-span-3'>
            <input name='address' value={form.address} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Locality'>
            <input name='locality' value={form.locality} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Sub Locality'>
            <input name='subLocality' value={form.subLocality} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='City'>
            <input name='city' value={form.city} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='District'>
            <input name='district' value={form.district} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='State'>
            <input name='state' value={form.state} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Country'>
            <input name='country' value={form.country} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Pincode'>
            <input name='pincode' value={form.pincode} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Landmark'>
            <input name='landmark' value={form.landmark} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Latitude'>
            <input name='latitude' type='number' step='any' value={form.latitude} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Longitude'>
            <input name='longitude' type='number' step='any' value={form.longitude} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Google Map Link' className='sm:col-span-2 lg:col-span-3'>
            <input name='googleMapLink' value={form.googleMapLink} onChange={handleChange} className={inputClass} placeholder='https://maps.google.com/...' />
          </Field>
        </Section>

        <Section title='Land Details'>
          <Field label='Survey Number'>
            <input name='surveyNumber' value={form.surveyNumber} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Gat Number'>
            <input name='gatNumber' value={form.gatNumber} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Khasra Number'>
            <input name='khasraNumber' value={form.khasraNumber} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Property Card Number'>
            <input name='propertyCardNumber' value={form.propertyCardNumber} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Village'>
            <input name='village' value={form.village} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Taluka'>
            <input name='taluka' value={form.taluka} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Land Type'>
            <select name='landType' value={form.landType} onChange={handleChange} className={inputClass}>
              <option value=''>Select land type</option>
              {LAND_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
          <Field label='Zoning'>
            <input name='zoning' value={form.zoning} onChange={handleChange} className={inputClass} placeholder='e.g. Residential Zone' />
          </Field>
        </Section>

        <Section title='Verification'>
          <Field label='Verification Status'>
            <select name='verificationStatus' value={form.verificationStatus} onChange={handleChange} className={inputClass}>
              {VERIFICATION_STATUSES.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
          </Field>
          <Field label='Verified By'>
            <select name='verifiedBy' value={form.verifiedBy} onChange={handleChange} className={inputClass}>
              <option value=''>Select employee</option>
              {employees.map((emp) => (
                <option key={emp._id} value={emp._id}>{emp.name}</option>
              ))}
            </select>
          </Field>
          <Field label='Verified Date'>
            <input name='verifiedDate' type='date' value={form.verifiedDate} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Remarks' className='sm:col-span-2 lg:col-span-3'>
            <textarea name='remarks' value={form.remarks} onChange={handleChange} rows={2} className={inputClass} />
          </Field>
        </Section>

        <Section title='Owner Details'>
          <Field label='Owner Name'>
            <input name='ownerName' value={form.ownerName} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Owner Phone'>
            <input name='ownerPhone' value={form.ownerPhone} onChange={handleChange} className={inputClass} />
          </Field>
          <Field label='Owner Email'>
            <input name='ownerEmail' type='email' value={form.ownerEmail} onChange={handleChange} className={inputClass} />
          </Field>
        </Section>

        <Section title='Description & Media'>
          <Field label='Description' className='sm:col-span-2 lg:col-span-3'>
            <textarea name='description' value={form.description} onChange={handleChange} rows={4} className={inputClass} placeholder='Full property description' />
          </Field>
          <Field label='Amenities (comma separated)' className='sm:col-span-2 lg:col-span-3'>
            <input name='amenities' value={form.amenities} onChange={handleChange} className={inputClass} placeholder='Lift, Gym, Pool, Security, Power Backup' />
          </Field>
          <Field label='Image URLs (one per line)' className='sm:col-span-2 lg:col-span-3'>
            <textarea name='imageUrls' value={form.imageUrls} onChange={handleChange} rows={3} className={inputClass} placeholder='https://...' />
          </Field>
          <Field label='Internal Notes' className='sm:col-span-2 lg:col-span-3'>
            <textarea name='notes' value={form.notes} onChange={handleChange} rows={2} className={inputClass} />
          </Field>
        </Section>

        <div className='flex gap-3'>
          <button
            type='submit'
            disabled={loading}
            className='bg-blue-600 text-white px-6 py-2.5 rounded-lg text-sm font-medium hover:bg-blue-700 disabled:opacity-50'
          >
            {loading ? 'Saving…' : isEdit ? 'Update Property' : 'List Property'}
          </button>
          <button
            type='button'
            onClick={() => navigate('/properties')}
            className='border border-gray-300 px-6 py-2.5 rounded-lg text-sm font-medium hover:bg-white'
          >
            Cancel
          </button>
        </div>
      </form>
    </div>
  )
}

export default AddProperty
