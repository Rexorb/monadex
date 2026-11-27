import { useState } from 'react'
import type { FormEvent } from 'react'
import { ArrowRight, Eye, EyeOff, Layers3, ShieldCheck, Sparkles } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import { friendlyError } from '../services/api'
import { Feedback } from '../components/ui/Feedback'

export function AuthPage({ mode }: { mode: 'login' | 'register' }) {
  const { login, register } = useAuth()
  const navigate = useNavigate()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [confirmation, setConfirmation] = useState('')
  const [visible, setVisible] = useState(false)
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const creating = mode === 'register'

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError('')
    if (creating && !/^[a-zA-Z0-9_]{3,32}$/.test(username)) {
      setError('Use de 3 a 32 caracteres: letras, números ou _.')
      return
    }
    if (creating && (password.length < 12 || password.length > 1024)) {
      setError('A senha precisa ter entre 12 e 1024 caracteres.')
      return
    }
    if (creating && password !== confirmation) {
      setError('As senhas não conferem.')
      return
    }
    setBusy(true)
    try {
      if (creating) await register(username, password, confirmation)
      else await login(username, password)
      navigate('/dashboard', { replace: true })
    } catch (failure) {
      setError(friendlyError(failure))
    } finally {
      setBusy(false)
    }
  }

  return <div className="auth-page">
    <div className="auth-story"><div className="auth-story__inner">
      <div className="auth-brand"><span className="brand-mark">λ</span><span>MONADEX</span></div>
      <div className="auth-story__hero"><span className="eyebrow"><Sparkles size={15} /> A FUNCTIONAL CARD COLLECTION</span>
        <h1>Cada carta,<br /><em>uma descoberta.</em></h1>
        <p>Sua biblioteca de cartas Pokémon TCG. Explore expansões, abra boosters gratuitos e acompanhe sua coleção crescer.</p>
        <div className="auth-story__features"><span><Layers3 size={18} /> Catálogo de cartas reais</span><span><ShieldCheck size={18} /> Coleção gratuita, sem compras</span></div>
      </div>
      <small>MONADEX <span>·</span> PROJETO ACADÊMICO</small>
    </div></div>
    <div className="auth-form-wrap"><div className="auth-form">
      <span className="eyebrow">{creating ? 'COMECE SUA COLEÇÃO' : 'BEM-VINDO DE VOLTA'}</span>
      <h2>{creating ? 'Crie sua conta' : 'Entre no Monadex'}</h2>
      <p className="muted">{creating ? 'Seu catálogo pessoal começa aqui.' : 'Sua coleção está esperando por você.'}</p>
      <form onSubmit={submit}>
        <label htmlFor="username">Nome de usuário</label>
        <input id="username" autoComplete="username" required minLength={creating ? 3 : undefined} maxLength={32} value={username} onChange={(e) => setUsername(e.target.value)} placeholder="Seu nome de usuário" />
        <label htmlFor="password">Senha</label>
        <div className="password-field"><input id="password" type={visible ? 'text' : 'password'} autoComplete={creating ? 'new-password' : 'current-password'} required minLength={creating ? 12 : undefined} value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Sua senha" />
          <button type="button" className="icon-button" onClick={() => setVisible(!visible)} aria-label={visible ? 'Ocultar senha' : 'Mostrar senha'}>{visible ? <EyeOff size={19} /> : <Eye size={19} />}</button></div>
        {creating && <><label htmlFor="confirmation">Confirmar senha</label><input id="confirmation" type="password" autoComplete="new-password" required value={confirmation} onChange={(e) => setConfirmation(e.target.value)} placeholder="Repita sua senha" /><small className="field-hint">Use pelo menos 12 caracteres.</small></>}
        {error && <Feedback message={error} />}
        <button className="button button--primary auth-submit" disabled={busy} type="submit">{busy ? 'Aguarde...' : creating ? 'Criar conta' : 'Entrar'} <ArrowRight size={18} /></button>
      </form>
      <p className="auth-switch">{creating ? 'Já tem uma conta?' : 'Ainda não tem uma conta?'} <Link to={creating ? '/login' : '/register'}>{creating ? 'Faça login' : 'Cadastre-se'}</Link></p>
    </div></div>
  </div>
}
