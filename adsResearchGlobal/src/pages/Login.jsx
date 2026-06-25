import React, { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

const Login = () => {
  const { user } = useAuth()
  const navigate = useNavigate()

  useEffect(() => {
    if (user) navigate('/dashboard', { replace: true })
  }, [user, navigate])
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { login } = useAuth()

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await login(email, password)
      const today = new Date().toISOString().slice(0, 10)
      const lastLoginDate = localStorage.getItem('crm_last_login_date')
      if (lastLoginDate !== today) {
        sessionStorage.setItem('crm_show_location_prompt', '1')
        localStorage.setItem('crm_last_login_date', today)
      }
      navigate('/dashboard')
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Login failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className='min-h-screen bg-gray-100 flex items-center justify-center p-4'>
      <div className='bg-white rounded-2xl shadow-xl p-8 w-full'>
        <h1 className='text-2xl font-bold text-gray-900 text-center mb-2'>Gamotech Software</h1>
        <p className='text-gray-600 text-sm text-center mb-6'>Sign in to your account</p>
        <form onSubmit={handleSubmit} className='space-y-4'>
          <div>
            <label className='block text-sm font-medium text-gray-700 mb-1'>Email</label>
            <input
              type='email'
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className='w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
              placeholder='you@example.com'
            />
          </div>
          <div>
            <label className='block text-sm font-medium text-gray-700 mb-1'>Password</label>
            <input
              type='password'
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className='w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500'
              placeholder='••••••••'
            />
          </div>
          {error && (
            <p className='text-red-600 text-sm'>{error}</p>
          )}
          <button
            type='submit'
            disabled={loading}
            className='w-full bg-blue-600 hover:bg-blue-700 text-white py-2.5 rounded-lg font-medium text-sm transition-colors disabled:opacity-50'
          >
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  )
}

export default Login
