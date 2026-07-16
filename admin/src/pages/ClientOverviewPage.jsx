import React, { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import api from '../api/axios'
import AdminCompanyShell from '../components/AdminCompanyShell'
import { AppIcon } from '../components/Icons'

const thead = 'text-left border-b bg-blue-600 text-white font-bold text-sm'
const th = 'px-4 py-3 text-left border-b border-blue-700/30'

const fmtDate = (d) => {
  if (!d) return '—'
  const x = new Date(d)
  return Number.isNaN(x.getTime())
    ? '—'
    : x.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' })
}

const fmtMoney = (n) => {
  if (n == null || n === '') return '—'
  const v = Number(n)
  return Number.isFinite(v) ? `₹${v.toLocaleString('en-IN')}` : '—'
}

const ClientOverviewPage = () => {
  const { tenantId, clientId } = useParams()
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    const load = async () => {
      if (!clientId || !tenantId) return
      try {
        setLoading(true)
        setError(null)
        const res = await api.get(`/companies/${tenantId}/clients/${clientId}/dashboard`)
        setData(res.data)
      } catch (err) {
        setError(err.response?.data?.message || err.message || 'Failed to load client overview')
        setData(null)
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [tenantId, clientId])

  const clientsPath = `/company/${tenantId}/clients`

  return (
    <AdminCompanyShell activeNav='clients'>
      {loading ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center text-sm text-gray-500'>
          Loading client overview…
        </div>
      ) : error || !data?.client ? (
        <div className='bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center'>
          <p className='text-red-600 text-sm'>{error || 'Client not found'}</p>
          <button
            type='button'
            onClick={() => navigate(clientsPath)}
            className='mt-4 text-blue-600 text-sm font-medium'
          >
            Back to Clients
          </button>
        </div>
      ) : (
        <>
          {(() => {
            const { client, billingSummary, projects = [], billings = [], tasks = [], workHistory = [] } = data
            const bs = billingSummary || {}
            return (
              <>
                <div className='flex flex-wrap items-start justify-between gap-4 mb-8'>
                  <div>
                    <div className='flex items-center gap-2 text-gray-500 text-sm mb-1'>
                      <AppIcon id='dashboard' className='size-4' />
                      <span>Client overview</span>
                    </div>
                    <h1 className='text-2xl font-bold text-gray-900'>{client.clientName}</h1>
                    <p className='text-gray-600 text-sm mt-1'>
                      Projects, billing, tasks, and activity for this client.
                    </p>
                  </div>
                  <button
                    type='button'
                    onClick={() => navigate(clientsPath)}
                    className='px-4 py-2 rounded-lg border border-gray-300 text-sm font-medium hover:bg-gray-50'
                  >
                    All clients
                  </button>
                </div>

                <div className='grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-8'>
                  <div className='bg-white rounded-lg shadow border border-gray-100 p-4'>
                    <h2 className='text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3'>Contact</h2>
                    <dl className='space-y-2 text-sm'>
                      <div>
                        <dt className='text-gray-500'>Email</dt>
                        <dd className='font-medium text-gray-900'>{client.mailId || '—'}</dd>
                      </div>
                      <div>
                        <dt className='text-gray-500'>Phone</dt>
                        <dd className='font-medium text-gray-900'>{client.clientNumber || '—'}</dd>
                      </div>
                      <div>
                        <dt className='text-gray-500'>Business type</dt>
                        <dd className='font-medium text-gray-900'>{client.businessType || '—'}</dd>
                      </div>
                    </dl>
                  </div>
                  <div className='bg-white rounded-lg shadow border border-gray-100 p-4'>
                    <h2 className='text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3'>Account</h2>
                    <dl className='space-y-2 text-sm'>
                      <div>
                        <dt className='text-gray-500'>Status</dt>
                        <dd className='font-medium text-gray-900'>{client.status || 'Active'}</dd>
                      </div>
                      <div>
                        <dt className='text-gray-500'>Client type</dt>
                        <dd className='font-medium text-gray-900'>{client.clientType || '—'}</dd>
                      </div>
                      <div>
                        <dt className='text-gray-500'>Onboarded by</dt>
                        <dd className='font-medium text-gray-900'>{client.onboardBy?.name || '—'}</dd>
                      </div>
                      <div>
                        <dt className='text-gray-500'>Onboard date</dt>
                        <dd className='font-medium text-gray-900'>{fmtDate(client.date)}</dd>
                      </div>
                    </dl>
                  </div>
                  <div className='bg-white rounded-lg shadow border border-gray-100 p-4'>
                    <h2 className='text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3'>
                      Location & services
                    </h2>
                    <dl className='space-y-2 text-sm'>
                      <div>
                        <dt className='text-gray-500'>Address</dt>
                        <dd className='font-medium text-gray-900'>
                          {[client.address, client.city, client.state, client.pincode].filter(Boolean).join(', ') || '—'}
                        </dd>
                      </div>
                      <div>
                        <dt className='text-gray-500'>Services</dt>
                        <dd className='font-medium text-gray-900'>
                          {Array.isArray(client.services) && client.services.length
                            ? client.services.join(', ')
                            : '—'}
                        </dd>
                      </div>
                    </dl>
                  </div>
                </div>

                <div className='grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8'>
                  <div className='bg-gradient-to-br from-slate-800 to-slate-900 text-white rounded-lg p-5 shadow'>
                    <p className='text-sm opacity-80'>Invoices generated</p>
                    <p className='text-3xl font-bold mt-1'>{bs.totalInvoicesGenerated ?? 0}</p>
                  </div>
                  <div className='bg-gradient-to-br from-emerald-700 to-emerald-900 text-white rounded-lg p-5 shadow'>
                    <p className='text-sm opacity-80'>Total paid (recorded)</p>
                    <p className='text-3xl font-bold mt-1'>{fmtMoney(bs.totalAmountPaid)}</p>
                  </div>
                  <div className='bg-gradient-to-br from-amber-700 to-amber-900 text-white rounded-lg p-5 shadow'>
                    <p className='text-sm opacity-80'>Remaining (by project billing)</p>
                    <p className='text-3xl font-bold mt-1'>{fmtMoney(bs.totalAmountPending)}</p>
                  </div>
                </div>

                <section className='mb-10'>
                  <h2 className='text-lg font-bold text-gray-900 mb-3'>Projects</h2>
                  <div className='bg-white rounded-lg shadow border border-gray-100 overflow-x-auto'>
                    <table className='w-full text-sm min-w-[900px]'>
                      <thead className={thead}>
                        <tr>
                          <th className={th}>Project</th>
                          <th className={th}>Team lead</th>
                          <th className={th}>Start</th>
                          <th className={th}>End / deadline</th>
                          <th className={th}>Project cost</th>
                          <th className={th}>Paid</th>
                          <th className={th}>Remaining</th>
                          <th className={th}>Status</th>
                        </tr>
                      </thead>
                      <tbody>
                        {projects.length === 0 ? (
                          <tr>
                            <td colSpan={8} className='px-4 py-8 text-center text-gray-500'>
                              No projects for this client.
                            </td>
                          </tr>
                        ) : (
                          projects.map((p) => (
                            <tr key={p._id} className='border-b border-gray-100 hover:bg-gray-50'>
                              <td className='px-4 py-3 font-medium text-gray-900'>{p.projectName}</td>
                              <td className='px-4 py-3'>{p.projectManager?.name || '—'}</td>
                              <td className='px-4 py-3'>{fmtDate(p.startDate)}</td>
                              <td className='px-4 py-3'>{fmtDate(p.deadline || p.endDate)}</td>
                              <td className='px-4 py-3'>{fmtMoney(p.projectCostBilling ?? p.budget)}</td>
                              <td className='px-4 py-3 text-emerald-700 font-medium'>
                                {fmtMoney(p.paidFromBilling)}
                              </td>
                              <td className='px-4 py-3 text-amber-800 font-medium'>
                                {fmtMoney(p.remainingAmount)}
                              </td>
                              <td className='px-4 py-3'>
                                <span className='px-2 py-0.5 rounded-full text-xs bg-gray-100'>
                                  {p.status || '—'}
                                </span>
                              </td>
                            </tr>
                          ))
                        )}
                      </tbody>
                    </table>
                  </div>
                </section>

                <section className='mb-10'>
                  <h2 className='text-lg font-bold text-gray-900 mb-3'>Invoices & billing</h2>
                  <div className='bg-white rounded-lg shadow border border-gray-100 overflow-x-auto'>
                    <table className='w-full text-sm min-w-[720px]'>
                      <thead className={thead}>
                        <tr>
                          <th className={th}>Invoice #</th>
                          <th className={th}>Type</th>
                          <th className={th}>Date</th>
                          <th className={th}>Payment amount</th>
                        </tr>
                      </thead>
                      <tbody>
                        {billings.length === 0 ? (
                          <tr>
                            <td colSpan={4} className='px-4 py-8 text-center text-gray-500'>
                              No invoices yet.
                            </td>
                          </tr>
                        ) : (
                          billings.map((b) => (
                            <tr
                              key={b._id}
                              role='button'
                              tabIndex={0}
                              onClick={() => navigate(`/company/${tenantId}/invoices/${b._id}`)}
                              onKeyDown={(e) => {
                                if (e.key === 'Enter' || e.key === ' ') {
                                  e.preventDefault()
                                  navigate(`/company/${tenantId}/invoices/${b._id}`)
                                }
                              }}
                              className='border-b border-gray-100 hover:bg-blue-50/60 transition-colors cursor-pointer'
                            >
                              <td className='px-4 py-3 font-mono text-xs'>{b.invoiceNumber || '—'}</td>
                              <td className='px-4 py-3'>{b.billType || '—'}</td>
                              <td className='px-4 py-3'>{fmtDate(b.createdAt)}</td>
                              <td className='px-4 py-3 font-medium'>
                                {fmtMoney(b.paymentDetails?.amount)}
                              </td>
                            </tr>
                          ))
                        )}
                      </tbody>
                    </table>
                  </div>
                </section>

                <section className='mb-10'>
                  <h2 className='text-lg font-bold text-gray-900 mb-1'>Task history</h2>
                  <p className='text-xs text-gray-500 mb-3'>Click a row to view full task details.</p>
                  <div className='bg-white rounded-lg shadow border border-gray-100 overflow-x-auto max-h-[480px] overflow-y-auto'>
                    <table className='w-full text-sm'>
                      <thead className={`${thead} sticky top-0 z-10`}>
                        <tr>
                          <th className={th}>Task</th>
                          <th className={th}>Project</th>
                          <th className={th}>Assign to</th>
                          <th className={th}>Assigned by</th>
                          <th className={th}>Assigned on</th>
                          <th className={th}>Status</th>
                          <th className={th}>Rating</th>
                          <th className={th}>Completed on</th>
                        </tr>
                      </thead>
                      <tbody>
                        {tasks.length === 0 ? (
                          <tr>
                            <td colSpan={8} className='px-4 py-8 text-center text-gray-500'>
                              No tasks.
                            </td>
                          </tr>
                        ) : (
                          tasks.map((t) => (
                            <tr
                              key={t._id}
                              role='button'
                              tabIndex={0}
                              onClick={() => {
                                if (String(t._id || '').startsWith('social-media-')) return
                                navigate(`/company/${tenantId}/tasks/${t._id}`)
                              }}
                              onKeyDown={(e) => {
                                if (e.key === 'Enter' || e.key === ' ') {
                                  e.preventDefault()
                                  if (String(t._id || '').startsWith('social-media-')) return
                                  navigate(`/company/${tenantId}/tasks/${t._id}`)
                                }
                              }}
                              className={`border-b border-gray-100 hover:bg-blue-50/60 transition-colors ${
                                String(t._id || '').startsWith('social-media-') ? '' : 'cursor-pointer'
                              }`}
                            >
                              <td className='px-4 py-3 font-medium max-w-[200px]'>
                                <span className='line-clamp-2'>{t.title}</span>
                              </td>
                              <td className='px-4 py-3 text-gray-600'>{t.project?.projectName || '—'}</td>
                              <td className='px-4 py-3 font-medium text-gray-900'>
                                {t.assignedTo?.name || '—'}
                              </td>
                              <td className='px-4 py-3'>
                                {t.assignedBy ? (
                                  <div>
                                    <div className='font-medium text-gray-900'>{t.assignedBy.name || '—'}</div>
                                    {t.assignedBy.email ? (
                                      <div className='text-xs text-gray-500 mt-0.5'>{t.assignedBy.email}</div>
                                    ) : null}
                                  </div>
                                ) : (
                                  '—'
                                )}
                              </td>
                              <td className='px-4 py-3 whitespace-nowrap'>{fmtDate(t.createdAt)}</td>
                              <td className='px-4 py-3'>{t.status}</td>
                              <td className='px-4 py-3 font-semibold text-amber-700'>
                                {t.rating?.score != null ? `${t.rating.score}/5` : '—'}
                              </td>
                              <td className='px-4 py-3 whitespace-nowrap'>
                                {t.status === 'Completed' ? fmtDate(t.completedAt || t.updatedAt) : '—'}
                              </td>
                            </tr>
                          ))
                        )}
                      </tbody>
                    </table>
                  </div>
                </section>

                <section>
                  <h2 className='text-lg font-bold text-gray-900 mb-3'>Work history</h2>
                  <p className='text-xs text-gray-500 mb-3'>
                    Recent invoices, project milestones, and task updates (newest first).
                  </p>
                  <ul className='space-y-2'>
                    {workHistory.length === 0 ? (
                      <li className='text-gray-500 text-sm'>No activity yet.</li>
                    ) : (
                      workHistory.map((w, i) => (
                        <li
                          key={`${w.type}-${w.id}-${i}`}
                          className='flex flex-wrap gap-3 items-start bg-white border border-gray-100 rounded-lg px-4 py-3 shadow-sm'
                        >
                          <span
                            className={`text-xs font-semibold px-2 py-0.5 rounded ${
                              w.type === 'invoice'
                                ? 'bg-cyan-100 text-cyan-900'
                                : w.type === 'project'
                                  ? 'bg-purple-100 text-purple-900'
                                  : 'bg-amber-100 text-amber-900'
                            }`}
                          >
                            {w.type}
                          </span>
                          <div className='flex-1 min-w-0'>
                            <p className='font-medium text-gray-900 text-sm'>{w.label}</p>
                            <p className='text-xs text-gray-600 mt-0.5'>{w.detail}</p>
                          </div>
                          <span className='text-xs text-gray-500 whitespace-nowrap'>{fmtDate(w.at)}</span>
                        </li>
                      ))
                    )}
                  </ul>
                </section>
              </>
            )
          })()}
        </>
      )}
    </AdminCompanyShell>
  )
}

export default ClientOverviewPage
