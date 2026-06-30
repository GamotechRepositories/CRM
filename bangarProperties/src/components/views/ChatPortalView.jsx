import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import api from '../../api/axios'
import { useAuth } from '../../context/AuthContext'

const getCurrentEmployeeId = (user) => user?._id || user?.id || null

const formatTime = (d) => {
  if (!d) return ''
  const date = new Date(d)
  const now = new Date()
  const isToday = date.toDateString() === now.toDateString()
  if (isToday) {
    return date.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
  }
  return date.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
}

const startOfDay = (value) => {
  const d = new Date(value)
  d.setHours(0, 0, 0, 0)
  return d.getTime()
}

const formatDayLabel = (value) => {
  const date = new Date(value)
  const now = new Date()
  const today = startOfDay(now)
  const msgDay = startOfDay(date)
  const yesterday = today - 24 * 60 * 60 * 1000

  if (msgDay === today) return 'Today'
  if (msgDay === yesterday) return 'Yesterday'

  return date.toLocaleDateString('en-IN', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    ...(date.getFullYear() !== now.getFullYear() ? { year: 'numeric' } : {}),
  })
}

const DateDivider = ({ label }) => (
  <div className='flex justify-center my-3 sticky top-2 z-[1]'>
    <span className='px-3 py-1 rounded-lg bg-[#ffffffd9] shadow-sm text-[12px] font-medium text-[#54656f]'>
      {label}
    </span>
  </div>
)

const buildChatItems = (messages) => {
  const items = []
  let lastDay = null

  messages.forEach((msg) => {
    const dayKey = startOfDay(msg.createdAt)
    if (dayKey !== lastDay) {
      items.push({
        type: 'date',
        id: `date-${dayKey}`,
        label: formatDayLabel(msg.createdAt),
      })
      lastDay = dayKey
    }
    items.push({ type: 'message', id: msg._id, data: msg })
  })

  return items
}

const toDateKey = (value = new Date()) => {
  const d = new Date(value)
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

const getPreviousDayKey = (dayKey) => {
  const d = new Date(`${dayKey}T12:00:00`)
  d.setDate(d.getDate() - 1)
  return toDateKey(d)
}

const mergeMessages = (older, current) => {
  const ids = new Set(current.map((m) => String(m._id)))
  const uniqueOlder = older.filter((m) => !ids.has(String(m._id)))
  return [...uniqueOlder, ...current]
}

const renderMessageBody = (body, mentions = [], mine = false) => {
  const text = String(body || '')
  if (!mentions.length) return text

  const parts = []
  let remaining = text
  const sorted = [...mentions].sort((a, b) => (b.name?.length || 0) - (a.name?.length || 0))

  while (remaining.length > 0) {
    let matched = false
    for (const mention of sorted) {
      const tag = `@${mention.name}`
      const idx = remaining.indexOf(tag)
      if (idx === 0) {
        parts.push(
          <span
            key={`${mention.employee}-${parts.length}`}
            className={`font-semibold ${mine ? 'text-[#027d56]' : 'text-[#128c7e]'}`}
          >
            {tag}
          </span>
        )
        remaining = remaining.slice(tag.length)
        matched = true
        break
      }
      if (idx > 0) {
        parts.push(<span key={`t-${parts.length}`}>{remaining.slice(0, idx)}</span>)
        remaining = remaining.slice(idx)
        matched = true
        break
      }
    }
    if (!matched) {
      parts.push(<span key={`end-${parts.length}`}>{remaining}</span>)
      break
    }
  }

  return parts
}

const getPollStats = (poll) => {
  const options = poll?.options || []
  const totalVotes = options.reduce((sum, opt) => sum + (opt.votes?.length || 0), 0)
  return { options, totalVotes }
}

const userVotedOnOption = (opt, currentUserId) =>
  (opt.votes || []).some((v) => String(v.employee?._id || v.employee) === String(currentUserId))

const PollMessage = ({ msg, currentUserId, onVote, voting }) => {
  const poll = msg.poll || {}
  const { options, totalVotes } = getPollStats(poll)

  return (
    <div className='min-w-[240px] max-w-full'>
      <div className='flex items-center gap-1.5 mb-2'>
        <span className='text-[#ffbb00]'>
          <svg viewBox='0 0 24 24' fill='currentColor' className='w-4 h-4'>
            <rect x='4' y='13' width='4' height='7' rx='1' />
            <rect x='10' y='9' width='4' height='11' rx='1' />
            <rect x='16' y='5' width='4' height='15' rx='1' />
          </svg>
        </span>
        <p className='font-semibold text-[#111b21] text-[15px] leading-snug'>{poll.question || msg.body}</p>
      </div>
      <div className='space-y-2'>
        {options.map((opt, idx) => {
          const count = opt.votes?.length || 0
          const pct = totalVotes > 0 ? Math.round((count / totalVotes) * 100) : 0
          const isSelected = userVotedOnOption(opt, currentUserId)
          return (
            <button
              key={`${msg._id}-opt-${idx}`}
              type='button'
              disabled={voting}
              onClick={() => onVote(msg._id, idx)}
              className={`w-full text-left rounded-lg border px-3 py-2 relative overflow-hidden transition ${
                isSelected
                  ? 'border-[#128c7e] bg-[#e7f8f3]'
                  : 'border-[#d1d7db] bg-white hover:bg-[#f5f6f6]'
              }`}
            >
              <div
                className='absolute inset-y-0 left-0 bg-[#128c7e]/15 transition-all'
                style={{ width: `${pct}%` }}
              />
              <div className='relative flex items-center justify-between gap-2'>
                <span className='text-sm text-[#111b21]'>{opt.text}</span>
                <span className='text-xs text-[#667781] shrink-0'>
                  {count} {count === 1 ? 'vote' : 'votes'}{totalVotes > 0 ? ` · ${pct}%` : ''}
                </span>
              </div>
            </button>
          )
        })}
      </div>
      <p className='text-[11px] text-[#667781] mt-2'>
        {totalVotes} {totalVotes === 1 ? 'vote' : 'votes'}
        {poll.allowMultiple ? ' · Multiple answers allowed' : ' · Tap an option to vote'}
      </p>
    </div>
  )
}

const ATTACH_OPTIONS = [
  {
    id: 'file',
    label: 'File',
    iconBg: 'bg-[#7f66ff]',
    icon: (
      <svg viewBox='0 0 24 24' fill='currentColor' className='w-5 h-5 text-white'>
        <path d='M4 4a2 2 0 0 1 2-2h5.5L20 10.5V20a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V4Zm7.5 0V9a1 1 0 0 0 1 1h5.5L11.5 2Z' />
      </svg>
    ),
  },
  {
    id: 'photos',
    label: 'Photos and videos',
    iconBg: 'bg-[#007bfc]',
    icon: (
      <svg viewBox='0 0 24 24' fill='currentColor' className='w-5 h-5 text-white'>
        <path d='M4 5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5Zm2 0v14h12V5H6Zm2 9 2.5-3 2 2.5L15 10l3 4H8Z' />
      </svg>
    ),
  },
  {
    id: 'poll',
    label: 'Poll',
    iconBg: 'bg-[#ffbb00]',
    icon: (
      <svg viewBox='0 0 24 24' fill='currentColor' className='w-5 h-5 text-white'>
        <rect x='4' y='13' width='4' height='7' rx='1' />
        <rect x='10' y='9' width='4' height='11' rx='1' />
        <rect x='16' y='5' width='4' height='15' rx='1' />
      </svg>
    ),
  },
  {
    id: 'event',
    label: 'Event',
    iconBg: 'bg-[#ff5961]',
    icon: (
      <svg viewBox='0 0 24 24' fill='currentColor' className='w-5 h-5 text-white'>
        <path d='M7 2a1 1 0 0 1 1 1v1h8V3a1 1 0 1 1 2 0v1h1a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h1V3a1 1 0 0 1 1-1Zm12 8H5v8h14v-8ZM7 12h2v2H7v-2Zm4 0h2v2h-2v-2Z' />
      </svg>
    ),
  },
  {
    id: 'ai-images',
    label: 'AI images',
    iconBg: 'bg-[#007bfc]',
    icon: (
      <svg viewBox='0 0 24 24' fill='currentColor' className='w-5 h-5 text-white'>
        <path d='M4 5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5Zm2 0v14h12V5H6Zm2 9 2.5-3 2 2.5L15 10l3 4H8Z' />
        <path d='M16.5 3.5 18 2l1.5 1.5L21 2l1.5 1.5L18 7l-1.5-1.5L15 7l1.5-1.5L15 4Z' className='text-[#8fd3ff]' />
      </svg>
    ),
  },
  {
    id: 'contact',
    label: 'Contact',
    iconBg: 'bg-[#ff7a45]',
    icon: (
      <svg viewBox='0 0 24 24' fill='currentColor' className='w-5 h-5 text-white'>
        <path d='M12 12a4 4 0 1 0-0.001-8.001A4 4 0 0 0 12 12Zm0 2c-4.418 0-8 2.015-8 4.5V20a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-1.5c0-2.485-3.582-4.5-8-4.5Z' />
      </svg>
    ),
  },
]

const ChatPortalView = () => {
  const { user } = useAuth()
  const currentUserId = getCurrentEmployeeId(user)

  const [integration, setIntegration] = useState(null)
  const [room, setRoom] = useState(null)
  const [messages, setMessages] = useState([])
  const [draft, setDraft] = useState('')
  const [pendingMentions, setPendingMentions] = useState([])
  const [loadingRoom, setLoadingRoom] = useState(true)
  const [loadingMessages, setLoadingMessages] = useState(false)
  const [sending, setSending] = useState(false)
  const [error, setError] = useState('')

  const [mentionOpen, setMentionOpen] = useState(false)
  const [mentionQuery, setMentionQuery] = useState('')
  const [mentionEmployees, setMentionEmployees] = useState([])
  const [loadingMentions, setLoadingMentions] = useState(false)

  const messagesEndRef = useRef(null)
  const scrollContainerRef = useRef(null)
  const topSentinelRef = useRef(null)
  const stickToBottomRef = useRef(true)
  const isPrependingRef = useRef(false)
  const inputRef = useRef(null)
  const fileInputRef = useRef(null)
  const photoInputRef = useRef(null)
  const attachMenuRef = useRef(null)
  const pollMs = integration?.pollingIntervalMs || 5000

  const [selectedFiles, setSelectedFiles] = useState([])
  const [attachMenuOpen, setAttachMenuOpen] = useState(false)
  const [attachNotice, setAttachNotice] = useState('')

  const [showPollModal, setShowPollModal] = useState(false)
  const [pollQuestion, setPollQuestion] = useState('')
  const [pollOptions, setPollOptions] = useState(['', ''])
  const [pollAllowMultiple, setPollAllowMultiple] = useState(false)
  const [creatingPoll, setCreatingPoll] = useState(false)
  const [votingPollId, setVotingPollId] = useState(null)
  const [oldestLoadedDay, setOldestLoadedDay] = useState(null)
  const [hasOlderDays, setHasOlderDays] = useState(false)
  const [loadingOlder, setLoadingOlder] = useState(false)

  const roomId = room?._id

  const scrollToBottom = () => {
    const container = scrollContainerRef.current
    if (container) {
      container.scrollTop = container.scrollHeight
      return
    }
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  const loadIntegration = useCallback(async () => {
    try {
      const res = await api.get('/chat/integration')
      setIntegration(res.data?.integration || null)
    } catch {
      setIntegration(null)
    }
  }, [])

  const loadTeamRoom = useCallback(async () => {
    if (!currentUserId) return
    try {
      const res = await api.get('/chat/team', { params: { employeeId: currentUserId } })
      setRoom(res.data?.conversation || null)
    } catch (e) {
      setError(e.response?.data?.message || 'Failed to load team chat')
    } finally {
      setLoadingRoom(false)
    }
  }, [currentUserId])

  const loadTodayMessages = useCallback(
    async (conversationId, { silent = false } = {}) => {
      if (!currentUserId || !conversationId) return
      if (!silent) setLoadingMessages(true)
      stickToBottomRef.current = true
      try {
        const res = await api.get(`/chat/conversations/${conversationId}/messages`, {
          params: { employeeId: currentUserId, day: 'today' },
        })
        setMessages(res.data?.messages || [])
        setOldestLoadedDay(res.data?.day || toDateKey())
        setHasOlderDays(Boolean(res.data?.hasOlder))
        await api.patch(`/chat/conversations/${conversationId}/read`, { employeeId: currentUserId })
      } catch (e) {
        if (!silent) setError(e.response?.data?.message || 'Failed to load messages')
      } finally {
        if (!silent) setLoadingMessages(false)
      }
    },
    [currentUserId]
  )

  const loadOlderMessages = useCallback(async () => {
    if (!currentUserId || !roomId || !oldestLoadedDay || !hasOlderDays || loadingOlder) return

    const previousDay = getPreviousDayKey(oldestLoadedDay)
    const container = scrollContainerRef.current
    const prevScrollHeight = container?.scrollHeight || 0

    setLoadingOlder(true)
    stickToBottomRef.current = false
    isPrependingRef.current = true
    try {
      const res = await api.get(`/chat/conversations/${roomId}/messages`, {
        params: { employeeId: currentUserId, day: previousDay },
      })
      const older = res.data?.messages || []
      setMessages((prev) => mergeMessages(older, prev))
      setOldestLoadedDay(res.data?.day || previousDay)
      setHasOlderDays(Boolean(res.data?.hasOlder))

      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          if (!container) return
          container.scrollTop = container.scrollHeight - prevScrollHeight
          isPrependingRef.current = false
        })
      })
    } catch (e) {
      isPrependingRef.current = false
      setError(e.response?.data?.message || 'Failed to load older messages')
    } finally {
      setLoadingOlder(false)
    }
  }, [currentUserId, roomId, oldestLoadedDay, hasOlderDays, loadingOlder])

  const handleMessagesScroll = useCallback(() => {
    const container = scrollContainerRef.current
    if (!container) return

    const distanceFromBottom = container.scrollHeight - container.scrollTop - container.clientHeight
    stickToBottomRef.current = distanceFromBottom < 96

    if (loadingOlder || !hasOlderDays) return
    if (container.scrollTop <= 96) {
      loadOlderMessages()
    }
  }, [loadingOlder, hasOlderDays, loadOlderMessages])

  useEffect(() => {
    if (!hasOlderDays || loadingOlder || loadingMessages || loadingRoom) return undefined

    const sentinel = topSentinelRef.current
    const root = scrollContainerRef.current
    if (!sentinel || !root) return undefined

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          loadOlderMessages()
        }
      },
      { root, rootMargin: '120px 0px 0px 0px', threshold: 0 }
    )

    observer.observe(sentinel)
    return () => observer.disconnect()
  }, [hasOlderDays, loadingOlder, loadingMessages, loadingRoom, loadOlderMessages, messages.length])

  const pollNewMessages = useCallback(async () => {
    if (!currentUserId || !roomId) return
    if (messages.length === 0) {
      loadTodayMessages(roomId, { silent: true })
      return
    }
    const last = messages[messages.length - 1]
    try {
      const res = await api.get(`/chat/conversations/${roomId}/messages`, {
        params: { employeeId: currentUserId, after: last.createdAt },
      })
      const incoming = res.data?.messages || []
      if (incoming.length > 0) {
        stickToBottomRef.current = true
        setMessages((prev) => {
          const ids = new Set(prev.map((m) => String(m._id)))
          const unique = incoming.filter((m) => !ids.has(String(m._id)))
          return [...prev, ...unique]
        })
        await api.patch(`/chat/conversations/${roomId}/read`, { employeeId: currentUserId })
      }
    } catch {
      /* ignore poll errors */
    }
  }, [currentUserId, roomId, messages, loadTodayMessages])

  const searchMentionEmployees = useCallback(async (query) => {
    setLoadingMentions(true)
    try {
      const res = await api.get('/chat/employees', { params: { search: query } })
      setMentionEmployees(res.data?.employees || [])
    } catch {
      setMentionEmployees([])
    } finally {
      setLoadingMentions(false)
    }
  }, [])

  const insertMention = (emp) => {
    const tag = `@${emp.name} `
    setDraft((prev) => {
      const atIndex = prev.lastIndexOf('@')
      if (atIndex >= 0 && mentionOpen) {
        return `${prev.slice(0, atIndex)}${tag}`
      }
      return `${prev}${tag}`
    })
    setPendingMentions((prev) => {
      if (prev.some((m) => String(m.employee) === String(emp._id))) return prev
      return [...prev, { employee: emp._id, name: emp.name }]
    })
    setMentionOpen(false)
    setMentionQuery('')
    inputRef.current?.focus()
  }

  const handleDraftChange = (e) => {
    const value = e.target.value
    setDraft(value)

    const caretText = value
    const atMatch = caretText.match(/@([^\s@]*)$/)
    if (atMatch) {
      setMentionOpen(true)
      setMentionQuery(atMatch[1])
    } else {
      setMentionOpen(false)
      setMentionQuery('')
    }
  }

  const sendMessage = async (e) => {
    e.preventDefault()
    const body = draft.trim()
    if (!body || !roomId || !currentUserId || sending) return
    setSending(true)
    setError('')
    try {
      const res = await api.post(`/chat/conversations/${roomId}/messages`, {
        employeeId: currentUserId,
        body,
        mentions: pendingMentions,
      })
      const msg = res.data?.message
      if (msg) {
        stickToBottomRef.current = true
        setMessages((prev) => [...prev, msg])
        setDraft('')
        setPendingMentions([])
        setMentionOpen(false)
      }
    } catch (e) {
      setError(e.response?.data?.message || 'Failed to send message')
    } finally {
      setSending(false)
    }
  }

  const handleFileSelect = (e) => {
    const files = Array.from(e.target.files || [])
    if (!files.length) return
    setSelectedFiles((prev) => [
      ...prev,
      ...files.map((file) => ({
        id: `${file.name}-${file.size}-${Date.now()}-${Math.random()}`,
        name: file.name,
        size: file.size,
        type: file.type,
        previewUrl: file.type.startsWith('image/') ? URL.createObjectURL(file) : null,
      })),
    ])
    e.target.value = ''
  }

  const removeSelectedFile = (id) => {
    setSelectedFiles((prev) => {
      const item = prev.find((f) => f.id === id)
      if (item?.previewUrl) URL.revokeObjectURL(item.previewUrl)
      return prev.filter((f) => f.id !== id)
    })
  }

  const formatFileSize = (bytes) => {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  const showAttachNotice = (text) => {
    setAttachNotice(text)
    setTimeout(() => setAttachNotice(''), 2500)
  }

  const handleAttachOption = (optionId) => {
    setAttachMenuOpen(false)
    if (optionId === 'file') {
      fileInputRef.current?.click()
      return
    }
    if (optionId === 'photos') {
      photoInputRef.current?.click()
      return
    }
    if (optionId === 'poll') {
      setPollQuestion('')
      setPollOptions(['', ''])
      setPollAllowMultiple(false)
      setShowPollModal(true)
      return
    }
    const label = ATTACH_OPTIONS.find((o) => o.id === optionId)?.label || 'Option'
    showAttachNotice(`${label} — coming soon`)
  }

  const resetPollModal = () => {
    setShowPollModal(false)
    setPollQuestion('')
    setPollOptions(['', ''])
    setPollAllowMultiple(false)
  }

  const updatePollOption = (index, value) => {
    setPollOptions((prev) => prev.map((opt, i) => (i === index ? value : opt)))
  }

  const addPollOption = () => {
    setPollOptions((prev) => (prev.length >= 10 ? prev : [...prev, '']))
  }

  const removePollOption = (index) => {
    setPollOptions((prev) => (prev.length <= 2 ? prev : prev.filter((_, i) => i !== index)))
  }

  const createPoll = async (e) => {
    e.preventDefault()
    const question = pollQuestion.trim()
    const options = pollOptions.map((o) => o.trim()).filter(Boolean)
    if (!question || options.length < 2 || !roomId || !currentUserId || creatingPoll) return

    setCreatingPoll(true)
    setError('')
    try {
      const res = await api.post(`/chat/conversations/${roomId}/polls`, {
        employeeId: currentUserId,
        question,
        options,
        allowMultiple: pollAllowMultiple,
      })
      const msg = res.data?.message
      if (msg) {
        stickToBottomRef.current = true
        setMessages((prev) => [...prev, msg])
        resetPollModal()
      }
    } catch (e) {
      setError(e.response?.data?.message || 'Failed to create poll')
    } finally {
      setCreatingPoll(false)
    }
  }

  const voteOnPoll = async (messageId, optionIndex) => {
    if (!currentUserId || votingPollId) return
    setVotingPollId(messageId)
    try {
      const res = await api.post(`/chat/messages/${messageId}/vote`, {
        employeeId: currentUserId,
        optionIndex,
      })
      const updated = res.data?.message
      if (updated) {
        setMessages((prev) => prev.map((m) => (String(m._id) === String(messageId) ? updated : m)))
      }
    } catch (e) {
      setError(e.response?.data?.message || 'Failed to vote')
    } finally {
      setVotingPollId(null)
    }
  }

  useEffect(() => {
    if (!attachMenuOpen) return
    const onClickOutside = (e) => {
      if (attachMenuRef.current && !attachMenuRef.current.contains(e.target)) {
        setAttachMenuOpen(false)
      }
    }
    document.addEventListener('mousedown', onClickOutside)
    return () => document.removeEventListener('mousedown', onClickOutside)
  }, [attachMenuOpen])

  useEffect(() => {
    loadIntegration()
  }, [loadIntegration])

  useEffect(() => {
    loadTeamRoom()
  }, [loadTeamRoom])

  useEffect(() => {
    if (roomId) {
      setMessages([])
      setOldestLoadedDay(null)
      setHasOlderDays(false)
      loadTodayMessages(roomId)
    } else {
      setMessages([])
    }
  }, [roomId, loadTodayMessages])

  useEffect(() => {
    if (isPrependingRef.current) return
    if (stickToBottomRef.current) scrollToBottom()
  }, [messages, roomId])

  useEffect(() => {
    const id = setInterval(pollNewMessages, pollMs)
    return () => clearInterval(id)
  }, [pollNewMessages, pollMs])

  useEffect(() => {
    if (!mentionOpen) return
    const timer = setTimeout(() => searchMentionEmployees(mentionQuery), 200)
    return () => clearTimeout(timer)
  }, [mentionOpen, mentionQuery, searchMentionEmployees])

  const mentionSuggestions = useMemo(() => {
    if (!mentionOpen) return []
    return mentionEmployees.filter((emp) => String(emp._id) !== String(currentUserId)).slice(0, 8)
  }, [mentionOpen, mentionEmployees, currentUserId])

  const chatItems = useMemo(() => buildChatItems(messages), [messages])

  if (!user) {
    return <div className='p-8 text-center text-gray-600'>Please log in to use team chat.</div>
  }

  if (!currentUserId) {
    return (
      <div className='p-8 text-center text-gray-600'>
        Your session is missing employee details. Please log out and log in again.
      </div>
    )
  }

  return (
    <div className='flex flex-col h-[calc(100vh-4rem)]'>
      {error && (
        <div className='mx-4 mt-3 px-4 py-2 rounded-lg bg-red-50 border border-red-100 text-sm text-red-800'>
          {error}
        </div>
      )}

      <div className='flex flex-1 min-h-0'>
        <div className='flex-1 flex flex-col bg-white overflow-hidden min-w-0'>
          <div className='px-5 py-3 border-b border-[#d1d7db] bg-[#075e54] text-white'>
            <p className='font-semibold'>{room?.title || 'Team Chat'}</p>
            <p className='text-xs text-white/80'>All employees · Type @ to tag someone</p>
          </div>

          <div
            ref={scrollContainerRef}
            onScroll={handleMessagesScroll}
            className='flex-1 overflow-y-auto px-4 py-3 space-y-1'
            style={{ backgroundColor: '#e5ddd5' }}
          >
            {loadingRoom || loadingMessages ? (
              <p className='text-sm text-gray-600 text-center py-8'>Loading messages…</p>
            ) : (
              <>
                <div ref={topSentinelRef} className='h-px w-full shrink-0' aria-hidden />
                {hasOlderDays && (
                  <div className='flex justify-center py-2'>
                    <button
                      type='button'
                      onClick={loadOlderMessages}
                      disabled={loadingOlder}
                      className='text-xs font-medium text-[#128c7e] bg-[#ffffffd9] hover:bg-white disabled:opacity-60 px-3 py-1.5 rounded-full shadow-sm border border-[#d1d7db]/80'
                    >
                      {loadingOlder ? 'Loading older messages…' : 'Load older messages'}
                    </button>
                  </div>
                )}
                {messages.length === 0 ? (
                  <>
                    <DateDivider label={formatDayLabel(new Date())} />
                    <p className='text-sm text-gray-600 text-center py-8'>No messages yet. Start the conversation!</p>
                  </>
                ) : (
                  chatItems.map((item) => {
                if (item.type === 'date') {
                  return <DateDivider key={item.id} label={item.label} />
                }

                const msg = item.data
                const senderId = msg.sender?._id || msg.sender
                const mine = String(senderId) === String(currentUserId)
                const isPoll = msg.messageType === 'poll'
                return (
                  <div
                    key={msg._id}
                    className={`flex w-full ${mine ? 'justify-end' : 'justify-start'}`}
                  >
                    <div
                      className={`relative max-w-[78%] min-w-[120px] px-3 py-2 text-[14.5px] leading-snug shadow-sm ${
                        mine
                          ? 'bg-[#d9fdd3] text-[#111b21] rounded-lg rounded-tr-none'
                          : 'bg-white text-[#111b21] rounded-lg rounded-tl-none'
                      } ${isPoll ? 'pb-6' : ''}`}
                    >
                      {!mine && (
                        <p className='text-[12.5px] font-semibold text-[#128c7e] mb-0.5 leading-tight'>
                          {msg.sender?.name || 'User'}
                        </p>
                      )}
                      {isPoll ? (
                        <PollMessage
                          msg={msg}
                          currentUserId={currentUserId}
                          onVote={voteOnPoll}
                          voting={votingPollId === msg._id}
                        />
                      ) : (
                        <p className='whitespace-pre-wrap break-words pr-14'>
                          {renderMessageBody(msg.body, msg.mentions || [], mine)}
                        </p>
                      )}
                      <span
                        className={`absolute bottom-1.5 right-2 text-[10px] leading-none text-[#667781]`}
                      >
                        {formatTime(msg.createdAt)}
                      </span>
                    </div>
                  </div>
                )
              })
                )}
              </>
            )}
            <div ref={messagesEndRef} />
          </div>

          <form onSubmit={sendMessage} className='p-3 border-t border-[#d1d7db] bg-[#f0f2f5] relative'>
            {mentionOpen && (
              <div className='absolute bottom-full left-4 right-4 mb-2 bg-white border border-gray-200 rounded-lg shadow-lg max-h-48 overflow-y-auto z-10'>
                {loadingMentions ? (
                  <p className='px-3 py-2 text-sm text-gray-500'>Searching employees…</p>
                ) : mentionSuggestions.length === 0 ? (
                  <p className='px-3 py-2 text-sm text-gray-500'>No employees found</p>
                ) : (
                  mentionSuggestions.map((emp) => (
                    <button
                      key={emp._id}
                      type='button'
                      onClick={() => insertMention(emp)}
                      className='w-full text-left px-3 py-2 hover:bg-blue-50 border-b border-gray-50 last:border-0'
                    >
                      <p className='text-sm font-medium text-gray-900'>{emp.name}</p>
                      <p className='text-xs text-gray-500'>
                        {emp.department ? `${emp.department} · ` : ''}
                        {emp.email}
                      </p>
                    </button>
                  ))
                )}
              </div>
            )}

            {selectedFiles.length > 0 && (
              <div className='flex flex-wrap gap-2 mb-2 px-1'>
                {selectedFiles.map((file) => (
                  <div
                    key={file.id}
                    className='flex items-center gap-2 bg-white border border-[#d1d7db] rounded-lg px-2 py-1.5 max-w-full shadow-sm'
                  >
                    {file.previewUrl ? (
                      <img
                        src={file.previewUrl}
                        alt={file.name}
                        className='w-10 h-10 rounded object-cover shrink-0'
                      />
                    ) : (
                      <div className='w-10 h-10 rounded bg-[#e9edef] flex items-center justify-center shrink-0 text-[#54656f]'>
                        <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='currentColor' className='w-5 h-5'>
                          <path
                            fillRule='evenodd'
                            d='M5.625 1.5H9a3.75 3.75 0 0 1 3.75 3.75v1.875c0 1.036.84 1.875 1.875 1.875H16.5a3.75 3.75 0 0 1 3.75 3.75v7.875c0 1.035-.84 1.875-1.875 1.875H5.625a1.875 1.875 0 0 1-1.875-1.875V3.375c0-1.036.84-1.875 1.875-1.875Zm6 16.5c.66 0 1.277-.19 1.797-.518l1.048 1.048a.75.75 0 0 0 1.06 0l2.829-2.829a.75.75 0 0 0 0-1.06l-1.048-1.048A3.375 3.375 0 1 0 11.625 18Z'
                            clipRule='evenodd'
                          />
                          <path d='M14.066 2.726a.75.75 0 0 1 .437-.695A3.75 3.75 0 0 1 16.5 2.25h.008c.988 0 1.864.48 2.404 1.227a.75.75 0 0 1-.437.695 3.75 3.75 0 0 0-1.872.26.75.75 0 0 1-.437-.696Z' />
                        </svg>
                      </div>
                    )}
                    <div className='min-w-0'>
                      <p className='text-xs font-medium text-[#111b21] truncate max-w-[140px]'>{file.name}</p>
                      <p className='text-[10px] text-[#667781]'>{formatFileSize(file.size)}</p>
                    </div>
                    <button
                      type='button'
                      onClick={() => removeSelectedFile(file.id)}
                      className='shrink-0 w-6 h-6 rounded-full text-[#667781] hover:bg-[#f0f2f5] hover:text-[#111b21]'
                      aria-label='Remove file'
                    >
                      ×
                    </button>
                  </div>
                ))}
              </div>
            )}

            <input
              ref={fileInputRef}
              type='file'
              multiple
              className='hidden'
              onChange={handleFileSelect}
              accept='.pdf,.doc,.docx,.xls,.xlsx,.txt,.zip,.rar'
            />
            <input
              ref={photoInputRef}
              type='file'
              multiple
              className='hidden'
              onChange={handleFileSelect}
              accept='image/*,video/*'
            />

            {attachNotice && (
              <div className='mb-2 px-3 py-2 rounded-lg bg-white border border-[#d1d7db] text-xs text-[#54656f] shadow-sm'>
                {attachNotice}
              </div>
            )}

            <div className='flex gap-2 items-end'>
              <div className='relative shrink-0' ref={attachMenuRef}>
                {attachMenuOpen && (
                  <div className='absolute bottom-full left-0 mb-2 w-56 bg-white rounded-xl shadow-lg border border-[#e9edef] py-1.5 z-20 overflow-hidden'>
                    {ATTACH_OPTIONS.map((option) => (
                      <button
                        key={option.id}
                        type='button'
                        onClick={() => handleAttachOption(option.id)}
                        className='w-full flex items-center gap-3 px-3 py-2.5 text-left hover:bg-[#f5f6f6] transition'
                      >
                        <span
                          className={`w-10 h-10 rounded-full flex items-center justify-center shrink-0 ${option.iconBg}`}
                        >
                          {option.icon}
                        </span>
                        <span className='text-[15px] text-[#111b21] truncate'>{option.label}</span>
                      </button>
                    ))}
                  </div>
                )}
                <button
                  type='button'
                  onClick={() => setAttachMenuOpen((open) => !open)}
                  className={`w-10 h-10 flex items-center justify-center rounded-full transition ${
                    attachMenuOpen
                      ? 'bg-[#128c7e] text-white rotate-45'
                      : 'text-[#54656f] hover:bg-[#e9edef] hover:text-[#111b21]'
                  }`}
                  aria-label='Attach'
                  title='Attach'
                >
                  <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='currentColor' className='w-6 h-6'>
                    <path
                      fillRule='evenodd'
                      d='M12 3.75a.75.75 0 0 1 .75.75v6.75h6.75a.75.75 0 0 1 0 1.5h-6.75v6.75a.75.75 0 0 1-1.5 0v-6.75H4.5a.75.75 0 0 1 0-1.5h6.75V4.5a.75.75 0 0 1 .75-.75Z'
                      clipRule='evenodd'
                    />
                  </svg>
                </button>
              </div>
              <input
                ref={inputRef}
                type='text'
                value={draft}
                onChange={handleDraftChange}
                placeholder='Type a message'
                className='flex-1 rounded-full border border-[#d1d7db] bg-white px-4 py-2.5 text-sm text-[#111b21] focus:outline-none focus:ring-1 focus:ring-[#128c7e]'
                disabled={sending || !roomId}
              />
              <button
                type='submit'
                disabled={!draft.trim() || sending || !roomId}
                className='shrink-0 w-10 h-10 flex items-center justify-center rounded-full bg-[#128c7e] text-white hover:bg-[#075e54] disabled:opacity-50 disabled:hover:bg-[#128c7e]'
                aria-label='Send message'
              >
                <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='currentColor' className='w-5 h-5'>
                  <path d='M3.478 2.404a.75.75 0 0 0-.926.941l2.432 7.905H13.5a.75.75 0 0 1 0 1.5H4.984l-2.432 7.905a.75.75 0 0 0 .926.94 60.519 60.519 0 0 0 18.445-8.986.75.75 0 0 0 0-1.218A60.517 60.517 0 0 0 3.478 2.404Z' />
                </svg>
              </button>
            </div>
          </form>
        </div>
      </div>

      {showPollModal && (
        <div className='fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4'>
          <div className='bg-white rounded-xl shadow-xl w-full max-w-md max-h-[90vh] flex flex-col overflow-hidden'>
            <div className='px-5 py-4 border-b border-[#e9edef] flex items-center justify-between'>
              <div>
                <h3 className='font-semibold text-[#111b21]'>Create poll</h3>
                <p className='text-xs text-[#667781] mt-0.5'>Ask a question and add options</p>
              </div>
              <button
                type='button'
                onClick={resetPollModal}
                className='text-[#667781] hover:text-[#111b21] text-2xl leading-none'
              >
                ×
              </button>
            </div>

            <form onSubmit={createPoll} className='flex flex-col flex-1 min-h-0'>
              <div className='p-5 space-y-4 overflow-y-auto flex-1'>
                <div>
                  <label className='block text-sm font-medium text-[#111b21] mb-1.5'>Question</label>
                  <input
                    type='text'
                    value={pollQuestion}
                    onChange={(e) => setPollQuestion(e.target.value)}
                    placeholder='Ask something…'
                    className='w-full rounded-lg border border-[#d1d7db] px-3 py-2.5 text-sm focus:outline-none focus:ring-1 focus:ring-[#128c7e]'
                    autoFocus
                  />
                </div>

                <div>
                  <label className='block text-sm font-medium text-[#111b21] mb-1.5'>Options</label>
                  <div className='space-y-2'>
                    {pollOptions.map((opt, idx) => (
                      <div key={`poll-opt-${idx}`} className='flex gap-2'>
                        <input
                          type='text'
                          value={opt}
                          onChange={(e) => updatePollOption(idx, e.target.value)}
                          placeholder={`Option ${idx + 1}`}
                          className='flex-1 rounded-lg border border-[#d1d7db] px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-[#128c7e]'
                        />
                        {pollOptions.length > 2 && (
                          <button
                            type='button'
                            onClick={() => removePollOption(idx)}
                            className='shrink-0 w-9 h-9 rounded-lg text-[#667781] hover:bg-[#f0f2f5]'
                            aria-label='Remove option'
                          >
                            ×
                          </button>
                        )}
                      </div>
                    ))}
                  </div>
                  {pollOptions.length < 10 && (
                    <button
                      type='button'
                      onClick={addPollOption}
                      className='mt-2 text-sm font-medium text-[#128c7e] hover:text-[#075e54]'
                    >
                      + Add option
                    </button>
                  )}
                </div>

                <label className='flex items-center gap-2 text-sm text-[#111b21] cursor-pointer'>
                  <input
                    type='checkbox'
                    checked={pollAllowMultiple}
                    onChange={(e) => setPollAllowMultiple(e.target.checked)}
                    className='rounded border-[#d1d7db] text-[#128c7e] focus:ring-[#128c7e]'
                  />
                  Allow multiple answers
                </label>
              </div>

              <div className='px-5 py-4 border-t border-[#e9edef] flex gap-2 justify-end'>
                <button
                  type='button'
                  onClick={resetPollModal}
                  className='px-4 py-2 rounded-lg text-sm font-medium text-[#667781] hover:bg-[#f0f2f5]'
                >
                  Cancel
                </button>
                <button
                  type='submit'
                  disabled={
                    creatingPoll ||
                    !pollQuestion.trim() ||
                    pollOptions.map((o) => o.trim()).filter(Boolean).length < 2
                  }
                  className='px-4 py-2 rounded-lg text-sm font-medium bg-[#128c7e] text-white hover:bg-[#075e54] disabled:opacity-50'
                >
                  {creatingPoll ? 'Creating…' : 'Send poll'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

export default ChatPortalView
