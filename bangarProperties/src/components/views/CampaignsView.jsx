import React, { useEffect, useMemo, useState } from 'react'
import api from '../../api/axios'
import { useNavigate } from 'react-router-dom'

// Format INR currency
const formatCurrency = (amount) => {
  const num = Number(amount) || 0
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(num)
}

// Format Date
const formatDate = (dateString) => {
  if (!dateString) return '—'
  const d = new Date(dateString)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  })
}

const formatDateTime = (dateString) => {
  if (!dateString) return '—'
  const d = new Date(dateString)
  if (Number.isNaN(d.getTime())) return '—'
  return d.toLocaleString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

const CampaignsView = () => {
  const navigate = useNavigate()

  // State
  const [campaigns, setCampaigns] = useState([])
  const [stats, setStats] = useState({
    totalCampaigns: 0,
    activeCampaigns: 0,
    totalMetaLeads: 0,
    totalSpend: 0,
    totalImpressions: 0,
    totalClicks: 0,
  })
  const [metaConfig, setMetaConfig] = useState({
    isConfigured: false,
    appId: '',
    adAccountId: '',
    hasToken: false,
    maskedToken: '',
    apiVersion: 'v26.0',
    lastSyncedAt: null,
    lastSyncStatus: '',
    lastSyncMessage: '',
  })
  const [loading, setLoading] = useState(true)
  const [syncing, setSyncing] = useState(false)
  const [testingConnection, setTestingConnection] = useState(false)
  const [testResult, setTestResult] = useState(null)
  const [error, setError] = useState(null)
  const [successToast, setSuccessToast] = useState(null)

  // Filters & Search
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('ALL')
  const [sortBy, setSortBy] = useState('recent')

  // Modals
  const [showConfigModal, setShowConfigModal] = useState(false)
  const [showLeadsDrawer, setShowLeadsDrawer] = useState(false)
  const [activeCampaign, setActiveCampaign] = useState(null)
  const [campaignLeads, setCampaignLeads] = useState([])
  const [loadingLeads, setLoadingLeads] = useState(false)
  const [leadSearch, setLeadSearch] = useState('')

  // Config Form
  const [configForm, setConfigForm] = useState({
    appId: '',
    adAccountId: '',
    systemUserToken: '',
    apiVersion: 'v26.0',
  })
  const [showToken, setShowToken] = useState(false)

  // Fetch campaigns from backend
  const fetchCampaigns = async () => {
    try {
      setLoading(true)
      setError(null)
      const res = await api.get('/campaigns')
      const data = res.data || {}
      setCampaigns(Array.isArray(data.campaigns) ? data.campaigns : [])
      if (data.stats) setStats(data.stats)
      if (data.metaConfig) setMetaConfig((prev) => ({ ...prev, ...data.metaConfig }))
    } catch (err) {
      console.error('Failed to load campaigns:', err)
      setError(err.response?.data?.message || err.message || 'Failed to fetch campaigns')
    } finally {
      setLoading(false)
    }
  }

  // Fetch Meta config
  const fetchMetaConfig = async () => {
    try {
      const res = await api.get('/campaigns/meta/config')
      const cfg = res.data?.config || {}
      setMetaConfig(cfg)
      setConfigForm({
        appId: cfg.appId || '',
        adAccountId: cfg.adAccountId || '',
        systemUserToken: '',
        apiVersion: cfg.apiVersion || 'v26.0',
      })
    } catch (err) {
      console.warn('Could not load Meta config:', err.message)
    }
  }

  useEffect(() => {
    fetchCampaigns()
    fetchMetaConfig()
  }, [])

  // Auto-dismiss toast
  useEffect(() => {
    if (successToast) {
      const timer = setTimeout(() => setSuccessToast(null), 5000)
      return () => clearTimeout(timer)
    }
  }, [successToast])

  // Save Meta Configuration
  const handleSaveConfig = async (e) => {
    if (e) e.preventDefault()
    try {
      setError(null)
      const res = await api.post('/campaigns/meta/config', configForm)
      setSuccessToast(res.data?.message || 'Meta configuration saved successfully!')
      fetchMetaConfig()
      return true
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to save configuration')
      return false
    }
  }

  // Test Meta Connection
  const handleTestConnection = async () => {
    try {
      setTestingConnection(true)
      setTestResult(null)
      setError(null)
      const res = await api.post('/campaigns/meta/test', configForm)
      setTestResult({
        success: true,
        message: res.data?.message || 'Connected successfully!',
        account: res.data?.account,
      })
    } catch (err) {
      setTestResult({
        success: false,
        message: err.response?.data?.message || err.message || 'Connection failed',
        details: err.response?.data?.details,
      })
    } finally {
      setTestingConnection(false)
    }
  }

  // Sync Campaigns & Leads from Meta Graph API v26
  const handleSyncMeta = async (withFormCreds = false) => {
    try {
      setSyncing(true)
      setError(null)
      const payload = withFormCreds ? configForm : {}
      const res = await api.post('/campaigns/meta/sync', payload)
      setSuccessToast(res.data?.message || 'Campaigns and leads synced successfully!')
      if (showConfigModal) setShowConfigModal(false)
      await fetchCampaigns()
      await fetchMetaConfig()
    } catch (err) {
      console.error('Sync failed:', err)
      setError(err.response?.data?.message || err.message || 'Sync failed from Meta Graph API v26')
    } finally {
      setSyncing(false)
    }
  }

  // View Leads for a campaign
  const handleViewLeads = async (campaign) => {
    setActiveCampaign(campaign)
    setShowLeadsDrawer(true)
    setLoadingLeads(true)
    setLeadSearch('')
    try {
      const res = await api.get(`/campaigns/${campaign.campaignId || campaign._id}/leads`)
      setCampaignLeads(Array.isArray(res.data?.leads) ? res.data.leads : [])
    } catch (err) {
      console.error('Failed to load campaign leads:', err)
      setCampaignLeads([])
    } finally {
      setLoadingLeads(false)
    }
  }

  // Filter & Sort campaigns
  const filteredCampaigns = useMemo(() => {
    return campaigns
      .filter((c) => {
        if (statusFilter !== 'ALL' && c.status !== statusFilter) return false
        if (search.trim()) {
          const q = search.toLowerCase().trim()
          const matchName = (c.name || '').toLowerCase().includes(q)
          const matchId = (c.campaignId || '').toLowerCase().includes(q)
          const matchObj = (c.objective || '').toLowerCase().includes(q)
          if (!matchName && !matchId && !matchObj) return false
        }
        return true
      })
      .sort((a, b) => {
        if (sortBy === 'leads') return (b.leadsCount || 0) - (a.leadsCount || 0)
        if (sortBy === 'spend') return (b.spend || 0) - (a.spend || 0)
        if (sortBy === 'name') return (a.name || '').localeCompare(b.name || '')
        return new Date(b.lastSyncedAt || b.createdAt || 0) - new Date(a.lastSyncedAt || a.createdAt || 0)
      })
  }, [campaigns, statusFilter, search, sortBy])

  // Filtered leads in drawer
  const filteredLeads = useMemo(() => {
    if (!leadSearch.trim()) return campaignLeads
    const q = leadSearch.toLowerCase().trim()
    return campaignLeads.filter((lead) => {
      return (
        (lead.name || '').toLowerCase().includes(q) ||
        (lead.contactNumber || '').toLowerCase().includes(q) ||
        (lead.email || '').toLowerCase().includes(q) ||
        (lead.adName || '').toLowerCase().includes(q)
      )
    })
  }, [campaignLeads, leadSearch])

  return (
    <div className='p-6 md:p-8 min-h-screen bg-slate-50 text-slate-800'>
      {/* Toast Notification */}
      {successToast && (
        <div className='fixed top-6 right-6 z-50 flex items-center gap-3 bg-emerald-600 text-white px-5 py-3 rounded-xl shadow-xl transition-all duration-300'>
          <svg className='size-5 shrink-0' fill='none' viewBox='0 0 24 24' stroke='currentColor'>
            <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={2} d='M5 13l4 4L19 7' />
          </svg>
          <span className='text-sm font-medium'>{successToast}</span>
          <button onClick={() => setSuccessToast(null)} className='ml-2 text-white/80 hover:text-white'>
            ✕
          </button>
        </div>
      )}

      {/* Top Header */}
      <div className='flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-8'>
        <div>
          <div className='flex items-center gap-3'>
            <div className='p-2 bg-gradient-to-tr from-blue-600 to-indigo-600 rounded-xl text-white shadow-md shadow-blue-500/20'>
              <svg className='size-6' fill='none' viewBox='0 0 24 24' stroke='currentColor'>
                <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={1.8} d='M11 5.882V19.24a1.76 1.76 0 01-3.417.592l-2.147-6.15M18 13a3 3 0 100-6M5.436 13.683A4.001 4.001 0 017 6h1.832c4.1 0 7.625-1.234 9.168-3v14c-1.543-1.766-5.067-3-9.168-3H7a3.988 3.988 0 01-1.564-.317z' />
              </svg>
            </div>
            <div>
              <h1 className='text-2xl md:text-3xl font-extrabold text-slate-900 tracking-tight'>
                Meta Ads Campaigns
              </h1>
              <p className='text-sm text-slate-500 mt-0.5'>
                Fetch and track leads by campaign via Meta Graph API v26.0
              </p>
            </div>
          </div>
        </div>

        {/* Action Buttons */}
        <div className='flex items-center gap-3 flex-wrap'>
          <button
            onClick={() => {
              setShowConfigModal(true)
              setTestResult(null)
            }}
            className='inline-flex items-center gap-2 px-4 py-2.5 bg-white hover:bg-slate-50 text-slate-700 border border-slate-300 rounded-xl font-medium text-sm shadow-sm transition-all hover:border-slate-400'
          >
            <span
              className={`size-2.5 rounded-full ${
                metaConfig.hasToken && metaConfig.adAccountId ? 'bg-emerald-500 animate-pulse' : 'bg-amber-400'
              }`}
            />
            <span>Meta API Settings</span>
          </button>

          <button
            onClick={() => handleSyncMeta(false)}
            disabled={syncing}
            className='inline-flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white rounded-xl font-semibold text-sm shadow-md shadow-blue-500/25 transition-all disabled:opacity-50'
          >
            <svg
              className={`size-4 ${syncing ? 'animate-spin' : ''}`}
              fill='none'
              viewBox='0 0 24 24'
              stroke='currentColor'
            >
              <path
                strokeLinecap='round'
                strokeLinejoin='round'
                strokeWidth={2}
                d='M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15'
              />
            </svg>
            <span>{syncing ? 'Fetching from Meta v26…' : 'Sync Meta Leads'}</span>
          </button>
        </div>
      </div>

      {/* Global Error Banner */}
      {error && (
        <div className='mb-6 p-4 bg-rose-50 border border-rose-200 rounded-2xl flex items-start gap-3 text-rose-800'>
          <svg className='size-5 shrink-0 mt-0.5 text-rose-600' fill='none' viewBox='0 0 24 24' stroke='currentColor'>
            <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={2} d='M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z' />
          </svg>
          <div className='flex-1 text-sm'>
            <p className='font-semibold'>Error</p>
            <p>{error}</p>
          </div>
          <button onClick={() => setError(null)} className='text-rose-500 hover:text-rose-700 text-sm'>✕</button>
        </div>
      )}

      {/* Configuration Status Notice (if not configured) */}
      {!metaConfig.hasToken && !metaConfig.adAccountId && !loading && (
        <div className='mb-8 p-6 bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200/80 rounded-2xl flex flex-col md:flex-row items-start md:items-center justify-between gap-4 shadow-sm'>
          <div className='flex items-start gap-4'>
            <div className='p-3 bg-blue-600 text-white rounded-xl shadow-md'>
              <svg className='size-6' fill='none' viewBox='0 0 24 24' stroke='currentColor'>
                <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={2} d='M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z' />
              </svg>
            </div>
            <div>
              <h3 className='font-bold text-slate-900 text-base'>Connect your Meta Ads Account</h3>
              <p className='text-sm text-slate-600 mt-1'>
                Provide your Meta App ID, Ads Account ID, and System User Page Token to automatically import campaigns and capture real-time leads via Graph API v26.0.
              </p>
            </div>
          </div>
          <button
            onClick={() => setShowConfigModal(true)}
            className='px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-semibold text-sm shrink-0 shadow-sm transition-all'
          >
            Configure Credentials
          </button>
        </div>
      )}

      {/* KPI Cards Overview */}
      <div className='grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8'>
        {/* Total Campaigns */}
        <div className='bg-white rounded-2xl p-5 border border-slate-200 shadow-sm hover:shadow-md transition-shadow'>
          <div className='flex items-center justify-between'>
            <span className='text-xs font-semibold text-slate-500 uppercase tracking-wider'>Total Campaigns</span>
            <div className='p-2 bg-indigo-50 text-indigo-600 rounded-xl'>
              <svg className='size-5' fill='none' viewBox='0 0 24 24' stroke='currentColor'>
                <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={1.8} d='M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10' />
              </svg>
            </div>
          </div>
          <p className='text-3xl font-extrabold text-slate-900 mt-3 tabular-nums'>{stats.totalCampaigns}</p>
          <div className='flex items-center gap-2 mt-2 text-xs'>
            <span className='inline-flex items-center gap-1 text-emerald-600 font-semibold'>
              <span className='size-2 rounded-full bg-emerald-500' />
              {stats.activeCampaigns} Active
            </span>
            <span className='text-slate-400'>•</span>
            <span className='text-slate-500'>{stats.totalCampaigns - stats.activeCampaigns} Inactive</span>
          </div>
        </div>

        {/* Total Leads Fetched */}
        <div className='bg-white rounded-2xl p-5 border border-slate-200 shadow-sm hover:shadow-md transition-shadow'>
          <div className='flex items-center justify-between'>
            <span className='text-xs font-semibold text-slate-500 uppercase tracking-wider'>Meta Leads</span>
            <div className='p-2 bg-emerald-50 text-emerald-600 rounded-xl'>
              <svg className='size-5' fill='none' viewBox='0 0 24 24' stroke='currentColor'>
                <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={1.8} d='M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z' />
              </svg>
            </div>
          </div>
          <p className='text-3xl font-extrabold text-emerald-600 mt-3 tabular-nums'>{stats.totalMetaLeads}</p>
          <div className='flex items-center justify-between mt-2 text-xs'>
            <span className='text-slate-500'>Imported into CRM</span>
            <button
              onClick={() => navigate('/leads')}
              className='text-blue-600 hover:text-blue-700 font-semibold hover:underline'
            >
              View in CRM Leads →
            </button>
          </div>
        </div>

        {/* Total Ad Spend */}
        <div className='bg-white rounded-2xl p-5 border border-slate-200 shadow-sm hover:shadow-md transition-shadow'>
          <div className='flex items-center justify-between'>
            <span className='text-xs font-semibold text-slate-500 uppercase tracking-wider'>Total Spend</span>
            <div className='p-2 bg-amber-50 text-amber-600 rounded-xl'>
              <svg className='size-5' fill='none' viewBox='0 0 24 24' stroke='currentColor'>
                <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={1.8} d='M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z' />
              </svg>
            </div>
          </div>
          <p className='text-3xl font-extrabold text-slate-900 mt-3 tabular-nums'>{formatCurrency(stats.totalSpend)}</p>
          <p className='text-xs text-slate-500 mt-2'>Reported by Meta Insights</p>
        </div>

        {/* Impressions & Clicks */}
        <div className='bg-white rounded-2xl p-5 border border-slate-200 shadow-sm hover:shadow-md transition-shadow'>
          <div className='flex items-center justify-between'>
            <span className='text-xs font-semibold text-slate-500 uppercase tracking-wider'>Impressions & Clicks</span>
            <div className='p-2 bg-purple-50 text-purple-600 rounded-xl'>
              <svg className='size-5' fill='none' viewBox='0 0 24 24' stroke='currentColor'>
                <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={1.8} d='M15 12a3 3 0 11-6 0 3 3 0 016 0z' />
                <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={1.8} d='M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z' />
              </svg>
            </div>
          </div>
          <div className='flex items-baseline gap-2 mt-3'>
            <p className='text-2xl font-extrabold text-slate-900 tabular-nums'>
              {Number(stats.totalImpressions || 0).toLocaleString()}
            </p>
            <span className='text-xs text-slate-500'>impr.</span>
          </div>
          <div className='flex items-center justify-between mt-2 text-xs text-slate-500'>
            <span>{Number(stats.totalClicks || 0).toLocaleString()} clicks</span>
            <span className='font-semibold text-indigo-600'>
              {stats.totalImpressions > 0
                ? `${((stats.totalClicks / stats.totalImpressions) * 100).toFixed(2)}% CTR`
                : '0% CTR'}
            </span>
          </div>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className='bg-white rounded-2xl p-4 border border-slate-200 shadow-sm mb-6 flex flex-col md:flex-row items-center justify-between gap-4'>
        {/* Search */}
        <div className='relative w-full md:w-80'>
          <svg className='size-4 text-slate-400 absolute left-3.5 top-3' fill='none' viewBox='0 0 24 24' stroke='currentColor'>
            <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={2} d='M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z' />
          </svg>
          <input
            type='text'
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder='Search campaigns by name or ID…'
            className='w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all'
          />
        </div>

        {/* Status Filters */}
        <div className='flex items-center gap-1.5 overflow-x-auto w-full md:w-auto pb-1 md:pb-0'>
          {['ALL', 'ACTIVE', 'PAUSED', 'ARCHIVED'].map((st) => (
            <button
              key={st}
              onClick={() => setStatusFilter(st)}
              className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-all ${
                statusFilter === st
                  ? 'bg-slate-900 text-white shadow-sm'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              {st === 'ALL' ? 'All Status' : st}
            </button>
          ))}
        </div>

        {/* Sort */}
        <div className='flex items-center gap-2 w-full md:w-auto justify-end'>
          <span className='text-xs text-slate-500 font-medium'>Sort:</span>
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value)}
            className='bg-slate-50 border border-slate-200 text-slate-700 text-xs font-semibold rounded-xl px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-blue-500/20'
          >
            <option value='recent'>Recently Synced</option>
            <option value='leads'>Most Leads</option>
            <option value='spend'>Highest Spend</option>
            <option value='name'>Name (A-Z)</option>
          </select>
        </div>
      </div>

      {/* Campaigns Listing */}
      {loading ? (
        <div className='bg-white rounded-2xl border border-slate-200 p-16 text-center text-slate-500 shadow-sm'>
          <div className='inline-block size-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mb-3' />
          <p className='text-sm font-medium'>Loading campaigns…</p>
        </div>
      ) : filteredCampaigns.length === 0 ? (
        <div className='bg-white rounded-2xl border border-dashed border-slate-300 p-16 text-center shadow-sm'>
          <div className='size-14 mx-auto mb-4 bg-slate-100 rounded-2xl flex items-center justify-center text-slate-400'>
            <svg className='size-8' fill='none' viewBox='0 0 24 24' stroke='currentColor'>
              <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={1.5} d='M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10' />
            </svg>
          </div>
          <h3 className='text-lg font-bold text-slate-900'>No campaigns found</h3>
          <p className='text-sm text-slate-500 mt-1 max-w-md mx-auto'>
            {campaigns.length === 0
              ? 'No campaigns have been synced yet. Click "Sync Meta Leads" or open Meta API Settings to enter your Ad Account credentials.'
              : 'No campaigns match your search and filter criteria.'}
          </p>
          {campaigns.length === 0 && (
            <button
              onClick={() => setShowConfigModal(true)}
              className='mt-5 inline-flex items-center gap-2 px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-semibold text-sm shadow-sm'
            >
              Configure & Sync Meta Ads
            </button>
          )}
        </div>
      ) : (
        <div className='grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6'>
          {filteredCampaigns.map((campaign) => {
            const isActive = campaign.status === 'ACTIVE'
            const isPaused = campaign.status === 'PAUSED'

            return (
              <div
                key={campaign.campaignId || campaign._id}
                className='bg-white rounded-2xl border border-slate-200/90 shadow-sm hover:shadow-lg transition-all duration-300 flex flex-col justify-between overflow-hidden group'
              >
                {/* Card Top Banner / Details */}
                <div className='p-6'>
                  <div className='flex items-start justify-between gap-3 mb-3'>
                    <div className='flex-1 min-w-0'>
                      <div className='flex items-center gap-2 mb-1.5 flex-wrap'>
                        <span
                          className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                            isActive
                              ? 'bg-emerald-100 text-emerald-800'
                              : isPaused
                              ? 'bg-amber-100 text-amber-800'
                              : 'bg-slate-100 text-slate-700'
                          }`}
                        >
                          <span
                            className={`size-1.5 rounded-full ${
                              isActive ? 'bg-emerald-500 animate-pulse' : isPaused ? 'bg-amber-500' : 'bg-slate-400'
                            }`}
                          />
                          {campaign.status || 'UNKNOWN'}
                        </span>

                        {campaign.objective && (
                          <span className='px-2 py-0.5 bg-blue-50 text-blue-700 rounded-md text-[11px] font-semibold tracking-wide'>
                            {campaign.objective}
                          </span>
                        )}
                      </div>

                      <h3 className='text-lg font-bold text-slate-900 group-hover:text-blue-600 transition-colors line-clamp-2' title={campaign.name}>
                        {campaign.name}
                      </h3>
                      <p className='text-xs text-slate-400 font-mono mt-1'>
                        ID: {campaign.campaignId}
                      </p>
                    </div>
                  </div>

                  {/* Metrics Grid */}
                  <div className='grid grid-cols-2 gap-3 p-3.5 bg-slate-50/80 rounded-xl border border-slate-100 my-4'>
                    <div>
                      <span className='text-[11px] uppercase font-semibold text-slate-500'>Leads Captured</span>
                      <p className='text-2xl font-black text-emerald-600 tabular-nums mt-0.5'>
                        {campaign.leadsCount || 0}
                      </p>
                    </div>

                    <div>
                      <span className='text-[11px] uppercase font-semibold text-slate-500'>Ad Spend</span>
                      <p className='text-base font-bold text-slate-800 tabular-nums mt-1'>
                        {formatCurrency(campaign.spend)}
                      </p>
                    </div>

                    <div>
                      <span className='text-[11px] uppercase font-semibold text-slate-500'>Impressions</span>
                      <p className='text-xs font-semibold text-slate-700 tabular-nums mt-0.5'>
                        {Number(campaign.impressions || 0).toLocaleString()}
                      </p>
                    </div>

                    <div>
                      <span className='text-[11px] uppercase font-semibold text-slate-500'>Clicks</span>
                      <p className='text-xs font-semibold text-slate-700 tabular-nums mt-0.5'>
                        {Number(campaign.clicks || 0).toLocaleString()}
                      </p>
                    </div>
                  </div>

                  {/* Dates */}
                  <div className='flex items-center justify-between text-xs text-slate-500 border-t border-slate-100 pt-3'>
                    <span>
                      {campaign.startTime ? `Started: ${formatDate(campaign.startTime)}` : 'Continuous'}
                    </span>
                    <span className='text-slate-400'>
                      Synced: {formatDate(campaign.lastSyncedAt || campaign.updatedAt)}
                    </span>
                  </div>
                </div>

                {/* Card Action Footer */}
                <div className='p-4 bg-slate-50/50 border-t border-slate-100 flex items-center justify-between gap-3'>
                  <span className='text-xs font-medium text-slate-500'>
                    {campaign.leadsCount > 0 ? `${campaign.leadsCount} lead records` : 'No leads recorded yet'}
                  </span>
                  <button
                    onClick={() => handleViewLeads(campaign)}
                    className='inline-flex items-center gap-1.5 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-xs font-bold shadow-sm transition-all'
                  >
                    <span>View Leads</span>
                    <svg className='size-3.5' fill='none' viewBox='0 0 24 24' stroke='currentColor'>
                      <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={2.5} d='M9 5l7 7-7 7' />
                    </svg>
                  </button>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {/* Meta Configuration Modal */}
      {showConfigModal && (
        <div className='fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fadeIn'>
          <div className='bg-white rounded-3xl max-w-xl w-full shadow-2xl border border-slate-200 overflow-hidden flex flex-col max-h-[90vh]'>
            {/* Modal Header */}
            <div className='p-6 border-b border-slate-100 flex items-center justify-between bg-gradient-to-r from-slate-900 to-indigo-950 text-white'>
              <div className='flex items-center gap-3'>
                <div className='p-2 bg-blue-600 rounded-xl'>
                  <svg className='size-5 text-white' fill='none' viewBox='0 0 24 24' stroke='currentColor'>
                    <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={2} d='M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z' />
                    <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={2} d='M15 12a3 3 0 11-6 0 3 3 0 016 0z' />
                  </svg>
                </div>
                <div>
                  <h2 className='text-lg font-bold'>Meta Ads API Configuration</h2>
                  <p className='text-xs text-blue-200'>Meta Graph API v26.0 Integration</p>
                </div>
              </div>
              <button
                onClick={() => setShowConfigModal(false)}
                className='text-slate-400 hover:text-white rounded-lg p-1'
              >
                ✕
              </button>
            </div>

            {/* Modal Body */}
            <div className='p-6 overflow-y-auto space-y-4'>
              {/* Test Result Banner */}
              {testResult && (
                <div
                  className={`p-4 rounded-2xl text-xs flex items-start gap-3 border ${
                    testResult.success
                      ? 'bg-emerald-50 border-emerald-200 text-emerald-800'
                      : 'bg-rose-50 border-rose-200 text-rose-800'
                  }`}
                >
                  <span className='text-base'>{testResult.success ? '✓' : '⚠️'}</span>
                  <div>
                    <p className='font-bold'>{testResult.message}</p>
                    {testResult.account && (
                      <p className='mt-1 text-emerald-700 font-mono'>
                        Account: {testResult.account.name} | Currency: {testResult.account.currency} | Status: {testResult.account.accountStatus}
                      </p>
                    )}
                  </div>
                </div>
              )}

              {/* Form Inputs */}
              <div>
                <label className='block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5'>
                  Meta App ID
                </label>
                <input
                  type='text'
                  value={configForm.appId}
                  onChange={(e) => setConfigForm({ ...configForm, appId: e.target.value })}
                  placeholder='e.g. 1092837465293847'
                  className='w-full px-4 py-2.5 bg-slate-50 border border-slate-300 rounded-xl text-sm font-mono focus:outline-none focus:ring-2 focus:ring-blue-500'
                />
                <p className='text-[11px] text-slate-400 mt-1'>From your Meta Developers App Dashboard</p>
              </div>

              <div>
                <label className='block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5'>
                  Meta Ads Account ID <span className='text-rose-500'>*</span>
                </label>
                <input
                  type='text'
                  value={configForm.adAccountId}
                  onChange={(e) => setConfigForm({ ...configForm, adAccountId: e.target.value })}
                  placeholder='e.g. act_1234567890123 or 1234567890123'
                  className='w-full px-4 py-2.5 bg-slate-50 border border-slate-300 rounded-xl text-sm font-mono focus:outline-none focus:ring-2 focus:ring-blue-500'
                />
                <p className='text-[11px] text-slate-400 mt-1'>
                  Ad Account ID from Meta Ads Manager (starts with act_ or numerical ID)
                </p>
              </div>

              <div>
                <div className='flex items-center justify-between mb-1.5'>
                  <label className='block text-xs font-bold text-slate-700 uppercase tracking-wider'>
                    Meta Page Token / System User Token <span className='text-rose-500'>*</span>
                  </label>
                  {metaConfig.hasToken && (
                    <span className='text-[11px] text-emerald-600 font-semibold bg-emerald-50 px-2 py-0.5 rounded-full'>
                      Token currently saved ({metaConfig.maskedToken})
                    </span>
                  )}
                </div>
                <div className='relative'>
                  <input
                    type={showToken ? 'text' : 'password'}
                    value={configForm.systemUserToken}
                    onChange={(e) => setConfigForm({ ...configForm, systemUserToken: e.target.value })}
                    placeholder={metaConfig.hasToken ? 'Enter new token to replace existing' : 'e.g. EAAB...'}
                    className='w-full pl-4 pr-11 py-2.5 bg-slate-50 border border-slate-300 rounded-xl text-sm font-mono focus:outline-none focus:ring-2 focus:ring-blue-500'
                  />
                  <button
                    type='button'
                    onClick={() => setShowToken(!showToken)}
                    className='absolute right-3 top-2.5 text-slate-400 hover:text-slate-600 text-xs font-medium'
                  >
                    {showToken ? 'Hide' : 'Show'}
                  </button>
                </div>
                <p className='text-[11px] text-slate-400 mt-1'>
                  Long-lived System User Access Token with permissions: <code className='bg-slate-100 px-1 py-0.5 rounded'>leads_retrieval</code>, <code className='bg-slate-100 px-1 py-0.5 rounded'>ads_read</code>, <code className='bg-slate-100 px-1 py-0.5 rounded'>pages_read_engagement</code>, <code className='bg-slate-100 px-1 py-0.5 rounded'>pages_manage_ads</code>.
                </p>
              </div>

              <div>
                <label className='block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5'>
                  Graph API Version
                </label>
                <input
                  type='text'
                  value={configForm.apiVersion}
                  onChange={(e) => setConfigForm({ ...configForm, apiVersion: e.target.value })}
                  placeholder='v26.0'
                  className='w-full px-4 py-2.5 bg-slate-50 border border-slate-300 rounded-xl text-sm font-mono focus:outline-none focus:ring-2 focus:ring-blue-500'
                />
                <p className='text-[11px] text-slate-400 mt-1'>Defaults to v26.0 as specified.</p>
              </div>
            </div>

            {/* Modal Actions */}
            <div className='p-6 bg-slate-50 border-t border-slate-100 flex flex-wrap items-center justify-between gap-3'>
              <button
                type='button'
                onClick={handleTestConnection}
                disabled={testingConnection || (!configForm.adAccountId && !metaConfig.adAccountId)}
                className='px-4 py-2 bg-white hover:bg-slate-100 text-slate-700 border border-slate-300 rounded-xl text-xs font-bold transition-all disabled:opacity-50'
              >
                {testingConnection ? 'Testing Connection…' : 'Test Connection'}
              </button>

              <div className='flex items-center gap-2'>
                <button
                  type='button'
                  onClick={handleSaveConfig}
                  className='px-4 py-2 bg-slate-800 hover:bg-slate-900 text-white rounded-xl text-xs font-bold transition-all'
                >
                  Save Configuration
                </button>

                <button
                  type='button'
                  onClick={() => {
                    handleSaveConfig().then((ok) => {
                      if (ok) handleSyncMeta(true)
                    })
                  }}
                  disabled={syncing}
                  className='px-4 py-2 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white rounded-xl text-xs font-bold shadow-md shadow-blue-500/20 transition-all disabled:opacity-50'
                >
                  {syncing ? 'Syncing Now…' : 'Save & Sync Leads'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Campaign Leads Drawer */}
      {showLeadsDrawer && activeCampaign && (
        <div className='fixed inset-0 z-50 flex justify-end bg-slate-900/50 backdrop-blur-sm animate-fadeIn'>
          <div className='bg-white w-full max-w-2xl h-full shadow-2xl flex flex-col animate-slideLeft'>
            {/* Drawer Header */}
            <div className='p-6 border-b border-slate-200 bg-slate-900 text-white flex items-start justify-between'>
              <div>
                <span className='px-2.5 py-0.5 bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 rounded-full text-xs font-bold uppercase'>
                  {activeCampaign.status}
                </span>
                <h2 className='text-xl font-bold mt-2'>{activeCampaign.name}</h2>
                <p className='text-xs text-slate-400 font-mono mt-1'>
                  Meta Campaign ID: {activeCampaign.campaignId}
                </p>
              </div>
              <button
                onClick={() => setShowLeadsDrawer(false)}
                className='text-slate-400 hover:text-white p-2 rounded-lg'
              >
                ✕
              </button>
            </div>

            {/* Drawer Search & Summary */}
            <div className='p-4 bg-slate-50 border-b border-slate-200 flex items-center justify-between gap-4'>
              <div className='relative flex-1'>
                <svg className='size-4 text-slate-400 absolute left-3 top-2.5' fill='none' viewBox='0 0 24 24' stroke='currentColor'>
                  <path strokeLinecap='round' strokeLinejoin='round' strokeWidth={2} d='M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z' />
                </svg>
                <input
                  type='text'
                  value={leadSearch}
                  onChange={(e) => setLeadSearch(e.target.value)}
                  placeholder='Search leads by name, phone, email…'
                  className='w-full pl-9 pr-3 py-1.5 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-blue-500'
                />
              </div>
              <span className='text-xs font-bold text-slate-700 whitespace-nowrap'>
                {filteredLeads.length} leads
              </span>
            </div>

            {/* Leads List */}
            <div className='flex-1 overflow-y-auto p-6 space-y-4'>
              {loadingLeads ? (
                <div className='py-20 text-center text-slate-400'>
                  <div className='inline-block size-6 border-2 border-blue-600 border-t-transparent rounded-full animate-spin mb-2' />
                  <p className='text-xs'>Loading campaign leads…</p>
                </div>
              ) : filteredLeads.length === 0 ? (
                <div className='py-20 text-center text-slate-400'>
                  <p className='text-sm font-semibold text-slate-700'>No leads recorded for this campaign</p>
                  <p className='text-xs mt-1 text-slate-500'>
                    When users submit lead generation forms on this campaign's ads, they will appear here.
                  </p>
                </div>
              ) : (
                filteredLeads.map((lead) => (
                  <div
                    key={lead._id || lead.externalLeadId}
                    className='p-4 bg-white rounded-2xl border border-slate-200 shadow-sm hover:border-blue-300 transition-all'
                  >
                    <div className='flex items-start justify-between gap-3 mb-2'>
                      <div>
                        <h4 className='font-bold text-slate-900 text-sm'>{lead.name || 'Meta Lead'}</h4>
                        {lead.businessName && lead.businessName !== lead.name && (
                          <p className='text-xs text-slate-500'>{lead.businessName}</p>
                        )}
                      </div>
                      <span className='px-2.5 py-0.5 bg-blue-50 text-blue-700 font-semibold text-[11px] rounded-full'>
                        {lead.status || 'Call not Received'}
                      </span>
                    </div>

                    <div className='grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs text-slate-600 my-3'>
                      <div className='flex items-center gap-2'>
                        <span className='text-slate-400 font-medium'>Phone:</span>
                        <a
                          href={`tel:${lead.contactNumber}`}
                          className='font-bold text-blue-600 hover:underline'
                        >
                          {lead.contactNumber}
                        </a>
                      </div>

                      {lead.email && (
                        <div className='flex items-center gap-2 truncate'>
                          <span className='text-slate-400 font-medium'>Email:</span>
                          <a href={`mailto:${lead.email}`} className='text-slate-700 hover:underline truncate'>
                            {lead.email}
                          </a>
                        </div>
                      )}

                      {lead.city && (
                        <div className='flex items-center gap-2'>
                          <span className='text-slate-400 font-medium'>City:</span>
                          <span className='text-slate-700'>{lead.city}</span>
                        </div>
                      )}

                      {lead.adName && (
                        <div className='flex items-center gap-2 truncate'>
                          <span className='text-slate-400 font-medium'>Ad:</span>
                          <span className='text-slate-700 truncate' title={lead.adName}>{lead.adName}</span>
                        </div>
                      )}
                    </div>

                    {lead.description && (
                      <div className='p-2.5 bg-slate-50 rounded-xl text-[11px] text-slate-600 font-mono whitespace-pre-wrap line-clamp-3 mb-3'>
                        {lead.description}
                      </div>
                    )}

                    <div className='flex items-center justify-between text-[11px] text-slate-400 pt-2 border-t border-slate-100'>
                      <span>Received: {formatDateTime(lead.createdAt)}</span>
                      <span className='font-mono'>ID: {lead.externalLeadId || lead._id}</span>
                    </div>
                  </div>
                ))
              )}
            </div>

            {/* Drawer Footer */}
            <div className='p-4 bg-slate-50 border-t border-slate-200 flex items-center justify-between'>
              <button
                onClick={() => setShowLeadsDrawer(false)}
                className='px-4 py-2 bg-white border border-slate-300 rounded-xl text-xs font-semibold text-slate-700'
              >
                Close
              </button>
              <button
                onClick={() => {
                  setShowLeadsDrawer(false)
                  navigate('/leads')
                }}
                className='px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-xs font-bold'
              >
                Open Full CRM Leads Page →
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default CampaignsView
