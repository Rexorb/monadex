import { useEffect, useState } from 'react'
import { ArrowRight, Gift, PackageOpen, RotateCcw, Sparkles } from 'lucide-react'
import { Link } from 'react-router-dom'
import { CardTile } from '../components/cards/CardTile'
import { Feedback } from '../components/ui/Feedback'
import { ApiError, api, friendlyError } from '../services/api'
import type { Card } from '../types/api'

export function BoostersPage() {
  const [available, setAvailable] = useState<number | null>(null)
  const [cards, setCards] = useState<Card[]>([])
  const [last, setLast] = useState<Card[]>([])
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  useEffect(() => {
    let active = true
    Promise.all([api.boosters(), api.last()]).then(([inventory, history]) => {
      if (active) { setAvailable(inventory.available); setLast(history.cards) }
    }).catch((failure) => { if (active) setError(friendlyError(failure)) })
    return () => { active = false }
  }, [])

  const open = async () => {
    if (busy || available === null || available <= 0) return
    setBusy(true)
    setError('')
    setNotice('')
    try {
      const result = await api.open()
      setCards(result.cards)
      setLast(result.cards)
      setAvailable((await api.boosters()).available)
      setNotice('Booster aberto! Estas seis cartas agora fazem parte da sua coleção.')
    } catch (failure) {
      if (failure instanceof ApiError && failure.status === 409) {
        api.boosters().then((inventory) => setAvailable(inventory.available)).catch(() => {})
      }
      setError(friendlyError(failure))
    } finally {
      setBusy(false)
    }
  }

  return <div className="page"><div className="page-heading"><div><span className="eyebrow">DESCUBRA NOVAS CARTAS</span><h1>Seus boosters</h1><p>Abra um pacote e descubra seis cartas escolhidas pelo servidor.</p></div><span className="counter-pill"><PackageOpen size={18} />{available ?? '—'} disponíveis</span></div>
    {error && <Feedback message={error} />}{notice && <Feedback message={notice} kind="success" />}
    <section className="booster-stage panel"><div className="booster-stage__copy"><span className="eyebrow"><Sparkles size={15} /> COLEÇÃO MONADEX</span><h2>O próximo achado<br />pode surpreender.</h2><p>Cada booster contém seis cartas do catálogo, com a última sempre acima da raridade comum.</p>
      <button className="button button--primary" disabled={busy || available === null || available <= 0} onClick={open}><PackageOpen size={19} />{busy ? 'Abrindo...' : 'Abrir booster'}<ArrowRight size={17} /></button>
      {available === 0 && <p className="booster-stage__empty"><Gift size={17} /> Sem boosters agora. <Link to="/dashboard">Confira sua recompensa diária.</Link></p>}
      <small>Gratuito · Sem compras · Cartas definidas pelo backend</small></div>
      <div className="booster-pack" aria-hidden="true"><div className="booster-pack__inner"><span>✧ &nbsp; MONADEX &nbsp; ✧</span><strong>λ</strong><span>A FUNCTIONAL CARD COLLECTION</span><div className="booster-pack__footer">6 CARTAS <span>✦</span> 1 DESCOBERTA</div></div></div></section>
    {cards.length > 0 && <section className="page-section"><div className="section-heading"><div><span className="eyebrow">RECÉM-DESCOBERTAS</span><h2>Suas seis cartas</h2></div><Link to="/collection" className="text-link">Ver minha coleção <ArrowRight size={17} /></Link></div><div className="cards-grid">{cards.map((card, index) => <CardTile key={`${card.externalId}-${index}`} card={card} />)}</div></section>}
    {last.length > 0 && <section className="page-section"><div className="section-heading"><div><span className="eyebrow">HISTÓRICO</span><h2>Último pacote aberto</h2></div><RotateCcw size={20} className="muted" /></div><div className="cards-grid">{last.map((card, index) => <CardTile key={`${card.externalId}-last-${index}`} card={card} />)}</div></section>}
  </div>
}
