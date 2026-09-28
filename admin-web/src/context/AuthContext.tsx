import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { login as apiLogin, logout as apiLogout } from '../api/auth'
import { fetchDashboardStats } from '../api/admin'
import { fetchProfile, profileImageUrl } from '../api/profile'
import {
  ApiError,
  getStoredToken,
  setStoredToken,
  setUnauthorizedHandler,
} from '../api/client'
import type { AuthUser } from '../types/auth'

const USER_KEY = 'access_admin_user'

interface AuthContextValue {
  user: AuthUser | null
  /** True while checking a stored session on first load. */
  initializing: boolean
  loading: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => void
  updateUser: (patch: Partial<AuthUser>) => void
  refreshProfile: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | null>(null)

function persistUser(user: AuthUser) {
  localStorage.setItem(USER_KEY, JSON.stringify({ ...user, token: '' }))
}

function loadStoredUser(): AuthUser | null {
  const token = getStoredToken()
  const raw = localStorage.getItem(USER_KEY)
  if (!token || !raw) return null
  try {
    const parsed = JSON.parse(raw) as AuthUser
    return { ...parsed, token }
  } catch {
    return null
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null)
  const [initializing, setInitializing] = useState(() => Boolean(getStoredToken()))
  const [loading, setLoading] = useState(false)

  const logout = useCallback(() => {
    apiLogout()
    localStorage.removeItem(USER_KEY)
    setStoredToken(null)
    setUser(null)
  }, [])

  const updateUser = useCallback((patch: Partial<AuthUser>) => {
    setUser((prev) => {
      if (!prev) return prev
      const next = { ...prev, ...patch }
      persistUser(next)
      return next
    })
  }, [])

  const refreshProfile = useCallback(async () => {
    const profile = await fetchProfile()
    updateUser({
      name: profile.name,
      email: profile.email,
      profileImage: profileImageUrl(profile),
    })
  }, [updateUser])

  useEffect(() => {
    setUnauthorizedHandler(logout)
    return () => setUnauthorizedHandler(null)
  }, [logout])

  useEffect(() => {
    let cancelled = false

    async function restoreSession() {
      const stored = loadStoredUser()
      if (!stored) {
        if (!cancelled) setInitializing(false)
        return
      }

      try {
        await fetchDashboardStats()
        if (!cancelled) {
          setUser(stored)
          try {
            await refreshProfile()
          } catch {
            /* keep stored user if profile fetch fails */
          }
        }
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) {
          logout()
        } else if (!cancelled) {
          // Keep cached session when the API is offline or temporarily unreachable.
          setUser(stored)
        }
      } finally {
        if (!cancelled) setInitializing(false)
      }
    }

    restoreSession()
    return () => {
      cancelled = true
    }
  }, [logout, refreshProfile])

  const login = useCallback(async (email: string, password: string) => {
    setLoading(true)
    try {
      const loggedIn = await apiLogin(email, password)
      persistUser(loggedIn)
      setUser(loggedIn)
      try {
        await refreshProfile()
      } catch {
        /* login still succeeds without profile photo */
      }
    } finally {
      setLoading(false)
    }
  }, [refreshProfile])

  const value = useMemo(
    () => ({ user, initializing, loading, login, logout, updateUser, refreshProfile }),
    [user, initializing, loading, login, logout, updateUser, refreshProfile],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
