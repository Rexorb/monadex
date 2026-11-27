import { useState } from 'react'
import { Boxes, ChevronRight, LayoutDashboard, LibraryBig, LogOut, Menu, PackageOpen, X } from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext'
import { friendlyError } from '../../services/api'
import { Feedback } from '../ui/Feedback'

const nav: { to: string; title: string; icon: LucideIcon }[] = [
  { to: '/dashboard', title: 'Visão geral', icon: LayoutDashboard },
  { to: '/boosters', title: 'Boosters', icon: PackageOpen },
  { to: '/collection', title: 'Minha coleção', icon: LibraryBig },
  { to: '/expansions', title: 'Expansões', icon: Boxes },
]

export function Shell() {
  const { username, logout } = useAuth()
  const [menuOpen, setMenuOpen] = useState(false)
  const [loggingOut, setLoggingOut] = useState(false)
  const [error, setError] = useState('')
  const navigate = useNavigate()
  const location = useLocation()
  const current = nav.find((item) => location.pathname.startsWith(item.to))?.title ?? 'Monadex'

  const signOut = async () => {
    setLoggingOut(true)
    setError('')
    try {
      await logout()
      navigate('/login', { replace: true })
    } catch (failure) {
      setError(friendlyError(failure))
    } finally {
      setLoggingOut(false)
    }
  }

  return <div className="app-shell">
    {menuOpen && <button className="mobile-scrim" aria-label="Fechar menu" onClick={() => setMenuOpen(false)} />}
    <aside className={`sidebar ${menuOpen ? 'sidebar--open' : ''}`}>
      <div className="sidebar__brand"><span className="brand-mark">λ</span><div><strong>MONADEX</strong><small>A Functional Card Collection</small></div>
        <button className="icon-button sidebar__close" aria-label="Fechar menu" onClick={() => setMenuOpen(false)}><X size={20} /></button>
      </div>
      <p className="sidebar__label">NAVEGAÇÃO</p>
      <nav aria-label="Navegação principal">{nav.map(({ to, title, icon: Icon }) =>
        <NavLink key={to} to={to} onClick={() => setMenuOpen(false)} className={({ isActive }) => `nav-link ${isActive ? 'nav-link--active' : ''}`}>
          <Icon size={19} strokeWidth={1.9} /> <span>{title}</span><ChevronRight className="nav-link__chevron" size={16} />
        </NavLink>)}</nav>
      <div className="sidebar__bottom"><div className="sidebar__note"><span>✦</span><p>Uma coleção construída carta por carta. Sem pressa, sem compras.</p></div>
        <button className="nav-link nav-link--logout" onClick={signOut} disabled={loggingOut}><LogOut size={19} />{loggingOut ? 'Saindo...' : 'Sair'}</button>
      </div>
    </aside>
    <div className="app-shell__main">
      <header className="topbar"><div className="topbar__left"><button className="icon-button menu-toggle" aria-label="Abrir menu" onClick={() => setMenuOpen(true)}><Menu size={23} /></button>
        <span className="topbar__crumb">MONADEX <ChevronRight size={15} /> <strong>{current}</strong></span></div>
        <div className="user-pill"><span className="user-pill__avatar">{username?.charAt(0).toUpperCase()}</span><span>{username}</span></div></header>
      <main className="main-content">{error && <Feedback message={error} />}<Outlet /></main>
    </div>
  </div>
}
