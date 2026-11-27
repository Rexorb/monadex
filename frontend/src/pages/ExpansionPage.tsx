import { useEffect, useState } from 'react'
import { ArrowLeft, Layers3 } from 'lucide-react'
import { Link, useParams } from 'react-router-dom'
import { OwnedCardTile } from '../components/cards/CardTile'
import { Feedback } from '../components/ui/Feedback'
import { Progress } from '../components/ui/Progress'
import { api, friendlyError } from '../services/api'
import type { ExpansionDetail } from '../types/api'

export function ExpansionPage() {
  const { id } = useParams()
  const [data, setData] = useState<ExpansionDetail | null>(null)
  const [error, setError] = useState('')
  const [limit, setLimit] = useState(24)
  useEffect(() => {
    let active = true
    const numericId = Number(id)
    if (!Number.isSafeInteger(numericId) || numericId < 1) {
      setError('Expansão inválida.')
      return
    }
    api.expansion(numericId).then((result) => { if (active) setData(result) })
      .catch((failure) => { if (active) setError(friendlyError(failure)) })
    return () => { active = false }
  }, [id])

  return <div className="page"><Link className="back-link" to="/expansions"><ArrowLeft size={18} /> Voltar às expansões</Link>
    {error && <Feedback message={error} />}
    {!data && !error && <p className="muted">Carregando expansão...</p>}
    {data && <><div className="expansion-hero panel"><div className="expansion-hero__symbol"><Layers3 size={52} /></div><div><span className="eyebrow">EXPANSÃO · {data.expansion.externalId}</span><h1>{data.expansion.name}</h1><p>{data.expansion.uniqueOwned} de {data.expansion.totalCards} cartas únicas adquiridas</p><Progress value={data.expansion.progressPercent} label="Progresso da expansão" /></div></div>
      <div className="section-heading"><div><span className="eyebrow">CATÁLOGO DA EXPANSÃO</span><h2>Todas as cartas</h2></div><span className="muted">{data.cards.length} cartas</span></div>
      {data.cards.length === 0 && <div className="empty-state"><Layers3 size={32} /><p>Não há cartas nesta expansão.</p></div>}
      <div className="cards-grid">{data.cards.slice(0, limit).map((entry) => <OwnedCardTile key={entry.card.externalId} entry={entry} />)}</div>
      {data.cards.length > limit && <button className="button button--outline load-more" onClick={() => setLimit(limit + 24)}>Mostrar mais cartas</button>}
    </>}
  </div>
}
