import { createContext, useCallback, useContext, useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { ApiError, api, clearCsrf } from '../services/api'

interface AuthState {
  username: string | null
  loading: boolean
  login: (username: string, password: string) => Promise<void>
  register: (username: string, password: string, confirmation: string) => Promise<void>
  logout: () => Promise<void>
  refresh: () => Promise<void>
}

const AuthContext = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [username, setUsername] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  const refresh = useCallback(async () => {
    try {
      setUsername((await api.dashboard()).username)
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) setUsername(null)
      else throw error
    }
  }, [])

  useEffect(() => {
    let mounted = true
    api.dashboard()
      .then((dashboard) => { if (mounted) setUsername(dashboard.username) })
      .catch(() => { if (mounted) setUsername(null) })
      .finally(() => { if (mounted) setLoading(false) })
    return () => { mounted = false }
  }, [])

  const login = async (name: string, password: string) => {
    const user = await api.login(name, password)
    setUsername(user.username)
  }
  const register = async (name: string, password: string, confirmation: string) => {
    const user = await api.register(name, password, confirmation)
    setUsername(user.username)
  }
  const logout = async () => {
    await api.logout()
    clearCsrf()
    setUsername(null)
  }

  return <AuthContext.Provider value={{ username, loading, login, register, logout, refresh }}>
    {children}
  </AuthContext.Provider>
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) throw new Error('AuthProvider ausente')
  return context
}
