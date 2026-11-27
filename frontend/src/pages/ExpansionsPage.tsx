import { useEffect, useState } from 'react'
import { ArrowRight, Boxes, Layers3 } from 'lucide-react'
import { Link } from 'react-router-dom'
import { Feedback } from '../components/ui/Feedback'
import { Progress } from '../components/ui/Progress'
import { api, friendlyError } from '../services/api'
import type { Expansion } from '../types/api'

export function ExpansionsPage() {
  const [expansions, setExpansions] = useState<Expansion[] | null>(null)
  const [error, setError] = useState('')
  useEffect(() => {
    let active = true
    api.expansions().then((result) => { if (active) setExpansions(result.expansions) })
      .catch((failure) => { if (active) setError(friendlyError(failure)) })
    return () => { active = false }
  }, [])

  return <div className="page"><div className="page-heading"><div><span className="eyebrow">EXPLORE O CATÁLOGO</span><h1>Expansões</h1><p>Cada expansão é um novo capítulo da sua coleção.</p></div><span className="counter-pill"><Boxes size={18} />{expansions?.length ?? '—'} expansões</span></div>
    {error && <Feedback message={error} />}
    {!expansions && !error && <p className="muted">Carregando expansões...</p>}
    {expansions?.length === 0 && <div className="empty-state"><Boxes size={32} /><h2>Nenhuma expansão disponível</h2><p>O catálogo ainda não foi importado no backend.</p></div>}
    <div className="expansion-grid">{expansions?.map((item) => <Link to={`/expansions/${item.id}`} key={item.id} className="expansion-card panel"><div className="expansion-card__banner"><div className="expansion-card__symbol"><Layers3 size={42} /></div><span className="expansion-card__code">{item.externalId}</span></div>
      <div className="expansion-card__body"><span className="eyebrow">EXPANSÃO · {item.releaseDate?.slice(0, 4) ?? 'CATÁLOGO'}</span><h2>{item.name}</h2><p>{item.uniqueOwned} de {item.totalCards} cartas únicas adquiridas</p><Progress value={item.progressPercent} label={`Progresso de ${item.name}`} /><span className="text-link">Explorar expansão <ArrowRight size={17} /></span></div></Link>)}</div>
  </div>
}
