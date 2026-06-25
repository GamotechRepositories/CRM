import React, { useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

const MyProfilePage = () => {
  const { user } = useAuth()
  const navigate = useNavigate()

  useEffect(() => {
    if (user?._id) {
      navigate(`/employees/${user._id}/profile`, { replace: true })
    }
  }, [user?._id, navigate])

  return <div className='p-8 text-sm text-gray-600'>Loading profile...</div>
}

export default MyProfilePage
