import { Navigate, Route, Routes } from 'react-router-dom'
import type { ReactNode } from 'react'
import { useAuth } from './contexts/AuthContext'
import { Shell } from './components/layout/Shell'
import { AuthPage } from './pages/AuthPage'
import { DashboardPage } from './pages/DashboardPage'
import { BoostersPage } from './pages/BoostersPage'
import { CollectionPage } from './pages/CollectionPage'
import { ExpansionsPage } from './pages/ExpansionsPage'
import { ExpansionPage } from './pages/ExpansionPage'

function Protected({ children }: { children: ReactNode }) {
  const { username, loading } = useAuth()
  if (loading) return <div className="loading-screen"><span className="brand-mark">λ</span><p>Carregando sua coleção...</p></div>
  return username ? children : <Navigate to="/login" replace />
}

function Guest({ children }: { children: ReactNode }) {
  const { username, loading } = useAuth()
  if (loading) return <div className="loading-screen"><span className="brand-mark">λ</span><p>Conectando ao Monadex...</p></div>
  return username ? <Navigate to="/dashboard" replace /> : children
}

export default function App() {
  return <Routes>
    <Route path="/login" element={<Guest><AuthPage mode="login" /></Guest>} />
    <Route path="/register" element={<Guest><AuthPage mode="register" /></Guest>} />
    <Route element={<Protected><Shell /></Protected>}>
      <Route path="/dashboard" element={<DashboardPage />} />
      <Route path="/boosters" element={<BoostersPage />} />
      <Route path="/collection" element={<CollectionPage />} />
      <Route path="/expansions" element={<ExpansionsPage />} />
      <Route path="/expansions/:id" element={<ExpansionPage />} />
    </Route>
    <Route path="*" element={<Navigate to="/dashboard" replace />} />
  </Routes>
}
