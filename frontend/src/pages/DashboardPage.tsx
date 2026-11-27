import { useEffect, useState } from 'react'
import { ArrowRight, BookOpen, ChartNoAxesCombined, Gift, Layers3, LibraryBig, Sparkles } from 'lucide-react'
import { Link } from 'react-router-dom'
import { api, friendlyError } from '../services/api'
import type { Dashboard, Rarity } from '../types/api'
import { Feedback } from '../components/ui/Feedback'
import { Progress } from '../components/ui/Progress'
import { rarityLabels } from '../components/cards/CardTile'

const rarities: Rarity[] = ['Common', 'Uncommon', 'Rare', 'UltraRare']

export function DashboardPage() {
  const [data, setData] = useState<Dashboard | null>(null)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [claiming, setClaiming] = useState(false)

  useEffect(() => {
    let active = true
    api.dashboard().then((result) => { if (active) setData(result) })
      .catch((failure) => { if (active) setError(friendlyError(failure)) })
    return () => { active = false }
  }, [])

  const claim = async () => {
    setClaiming(true)
    setError('')
    setNotice('')
    try {
      const result = await api.claim()
      const updated = await api.dashboard()
      setData(updated)
      setNotice(result.grantedNow ? 'Seu booster gratuito foi adicionado ao inventário!' : 'Você já recebeu o booster de hoje.')
    } catch (failure) {
      setError(friendlyError(failure))
    } finally {
      setClaiming(false)
    }
  }

  return <div className="page page--dashboard">
    <div className="page-heading"><div><span className="eyebrow">SEU ESPAÇO DE COLEÇÃO</span><h1>Olá, {data?.username ?? 'colecionador'} <span className="heading-spark">✦</span></h1><p>Um panorama das cartas e descobertas da sua coleção.</p></div><Link className="button button--outline" to="/collection"><LibraryBig size={18} /> Ver coleção</Link></div>
    {error && <Feedback message={error} />}{notice && <Feedback message={notice} kind="success" />}
    {!data && !error && <p className="muted">Carregando seus dados...</p>}
    {data && <>
      <div className="stats-grid">
        <div className="stat-card"><span className="stat-card__icon stat-card__icon--violet"><Layers3 size={23} /></span><span>Boosters disponíveis</span><strong>{data.boosters}</strong><small>Prontos para abrir</small></div>
        <div className="stat-card"><span className="stat-card__icon stat-card__icon--blue"><BookOpen size={23} /></span><span>Total de cartas</span><strong>{data.totalCards}</strong><small>Incluindo cópias repetidas</small></div>
        <div className="stat-card"><span className="stat-card__icon stat-card__icon--green"><LibraryBig size={23} /></span><span>Cartas únicas</span><strong>{data.uniqueCards}</strong><small>De {data.catalogTotal} no catálogo</small></div>
        <div className="stat-card"><span className="stat-card__icon stat-card__icon--amber"><ChartNoAxesCombined size={23} /></span><span>Progresso geral</span><strong>{data.progressPercent.toFixed(1).replace('.', ',')}<i>%</i></strong><small>Do catálogo conhecido</small></div>
      </div>
      <div className="dashboard-grid">
        <section className="panel reward-panel"><span className="eyebrow"><Gift size={15} /> RECOMPENSA GRATUITA</span><h2>Um booster por dia</h2><p>Uma nova oportunidade de encontrar cartas para a sua biblioteca. Sem obrigação de voltar todos os dias.</p>
          {data.dailyReward.claimed ? <div className="reward-panel__claimed"><span className="status-dot" /> Booster de hoje recebido <small>{data.dailyReward.date}</small></div> :
            <button className="button button--primary" disabled={claiming} onClick={claim}><Gift size={18} />{claiming ? 'Solicitando...' : 'Receber booster gratuito'}</button>}
          {data.boosters > 0 && <Link className="text-link" to="/boosters">Ir para os boosters <ArrowRight size={16} /></Link>}
        </section>
        <section className="panel progress-panel"><div className="panel__title"><div><span className="eyebrow">SEU PROGRESSO</span><h2>Biblioteca de cartas</h2></div><span className="panel__icon"><Sparkles size={20} /></span></div>
          <p className="muted">{data.uniqueCards} de {data.catalogTotal} cartas distintas encontradas</p><Progress value={data.progressPercent} label="Progresso geral da coleção" />
          <div className="progress-panel__footer"><span>Explorar o catálogo completo</span><Link to="/collection" aria-label="Explorar coleção"><ArrowRight size={19} /></Link></div>
        </section>
      </div>
      <section className="panel rarity-panel"><div className="panel__title"><div><span className="eyebrow">VISÃO DA COLEÇÃO</span><h2>Cartas por raridade</h2></div><span className="muted">Contagem de cópias</span></div>
        <div className="rarity-grid">{rarities.map((rarity) => <div key={rarity} className={`rarity-stat rarity-${rarity.toLowerCase()}`}><span className="rarity-stat__gem">◆</span><div><small>{rarityLabels[rarity]}</small><strong>{data.byRarity[rarity]}</strong></div></div>)}</div>
      </section>
    </>}
  </div>
}
