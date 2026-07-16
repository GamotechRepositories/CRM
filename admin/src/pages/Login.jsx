import React, { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import Logo from '../assets/logo.jpg'

const MailIcon = () => (
  <svg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' strokeWidth={1.5} stroke='currentColor' className='w-5 h-5 text-gray-400'>
    <path strokeLinecap='round' strokeLinejoin='round' d='M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75' />
  </svg>
)

const LockIcon = () => (
  <svg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' strokeWidth={1.5} stroke='currentColor' className='w-5 h-5 text-gray-400'>
    <path strokeLinecap='round' strokeLinejoin='round' d='M16.5 10.5V6.75a4.5 4.5 0 1 0-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 0 0 2.25-2.25v-6.75a2.25 2.25 0 0 0-2.25-2.25H6.75a2.25 2.25 0 0 0-2.25 2.25v6.75a2.25 2.25 0 0 0 2.25 2.25Z' />
  </svg>
)

const EyeIcon = ({ open }) => (
  <svg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' strokeWidth={1.5} stroke='currentColor' className='w-5 h-5 text-gray-400'>
    {open ? (
      <path strokeLinecap='round' strokeLinejoin='round' d='M3.98 8.223A10.477 10.477 0 0 0 1.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.451 10.451 0 0 1 12 4.5c4.756 0 8.773 3.162 10.065 7.498a10.522 10.522 0 0 1-4.293 5.774M6.228 6.228 3 3m3.228 3.228 3.65 3.65m7.894 7.894L21 21m-3.228-3.228-3.65-3.65m0 0a3 3 0 1 0-4.243-4.243m4.242 4.242L9.88 9.88' />
    ) : (
      <path strokeLinecap='round' strokeLinejoin='round' d='M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z' />
    )}
  </svg>
)

const REMEMBER_KEY = 'central_admin_remember_email'

const Login = () => {
  const { user, login } = useAuth()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [remember, setRemember] = useState(false)
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [info, setInfo] = useState('')
  const [loading, setLoading] = useState(false)
  const year = new Date().getFullYear()

  useEffect(() => {
    if (user) navigate('/', { replace: true })
  }, [user, navigate])

  useEffect(() => {
    const saved = localStorage.getItem(REMEMBER_KEY)
    if (saved) {
      setEmail(saved)
      setRemember(true)
    }
  }, [])

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setInfo('')
    setLoading(true)
    try {
      await login(email, password)
      if (remember) localStorage.setItem(REMEMBER_KEY, email)
      else localStorage.removeItem(REMEMBER_KEY)
      navigate('/')
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Login failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className='min-h-screen flex flex-col bg-gradient-to-br from-indigo-50 via-white to-violet-50'>
      <div className='flex-1 flex items-center justify-center p-6 sm:p-10'>
        <div className='w-full max-w-md'>
          <div className='bg-white rounded-2xl border border-gray-100 shadow-xl shadow-gray-200/50 p-8 sm:p-10'>
            <div className='flex justify-center mb-6'>
              <img
                src={Logo}
                alt='Central Admin logo'
                className='max-w-[280px] w-full h-auto object-contain'
              />
            </div>
            <div className='text-center mb-8'>
              <h1 className='text-xl font-bold text-slate-900'>Central Admin</h1>
              <p className='text-sm text-gray-500 mt-1'>Sign in to manage all company CRMs</p>
            </div>

            <form onSubmit={handleSubmit} className='space-y-5'>
              <div>
                <label htmlFor='email' className='block text-sm font-semibold text-slate-800 mb-1.5'>Email Address</label>
                <div className='relative'>
                  <span className='absolute left-3 top-1/2 -translate-y-1/2'><MailIcon /></span>
                  <input
                    id='email'
                    type='email'
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                    autoComplete='email'
                    className='w-full border border-gray-200 rounded-xl pl-10 pr-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent'
                    placeholder='Enter your email'
                  />
                </div>
              </div>

              <div>
                <label htmlFor='password' className='block text-sm font-semibold text-slate-800 mb-1.5'>Password</label>
                <div className='relative'>
                  <span className='absolute left-3 top-1/2 -translate-y-1/2'><LockIcon /></span>
                  <input
                    id='password'
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    autoComplete='current-password'
                    className='w-full border border-gray-200 rounded-xl pl-10 pr-11 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent'
                    placeholder='Enter your password'
                  />
                  <button
                    type='button'
                    onClick={() => setShowPassword((v) => !v)}
                    className='absolute right-3 top-1/2 -translate-y-1/2 p-0.5 rounded hover:bg-gray-100'
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                  >
                    <EyeIcon open={showPassword} />
                  </button>
                </div>
              </div>

              <div className='flex items-center justify-between text-sm'>
                <label className='flex items-center gap-2 text-gray-600 cursor-pointer'>
                  <input
                    type='checkbox'
                    checked={remember}
                    onChange={(e) => setRemember(e.target.checked)}
                    className='rounded border-gray-300 text-indigo-600 focus:ring-indigo-500'
                  />
                  Remember me
                </label>
                <button
                  type='button'
                  onClick={() => { setError(''); setInfo('Use the root admin credentials to access this panel.') }}
                  className='font-medium text-indigo-600 hover:text-indigo-700'
                >
                  Forgot password?
                </button>
              </div>

              {error && <p className='text-red-600 text-sm bg-red-50 border border-red-100 rounded-lg px-3 py-2'>{error}</p>}
              {info && <p className='text-indigo-700 text-sm bg-indigo-50 border border-indigo-100 rounded-lg px-3 py-2'>{info}</p>}

              <button
                type='submit'
                disabled={loading}
                className='w-full bg-indigo-600 hover:bg-indigo-700 text-white py-3 rounded-xl font-semibold text-sm transition-colors disabled:opacity-50 shadow-lg shadow-indigo-200'
              >
                {loading ? 'Signing in…' : 'Sign In'}
              </button>
            </form>
          </div>
          <p className='text-center text-xs text-gray-400 mt-6'>© {year} MultiCRM Central Admin</p>
        </div>
      </div>
    </div>
  )
}

export default Login
