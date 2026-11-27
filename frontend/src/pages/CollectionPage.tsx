import { useEffect, useState } from 'react'
import { LibraryBig, Search, SlidersHorizontal } from 'lucide-react'
import { OwnedCardTile } from '../components/cards/CardTile'
import { Feedback } from '../components/ui/Feedback'
import { api, friendlyError } from '../services/api'
import type { CollectionResponse, Expansion, Rarity } from '../types/api'

const rarities: Rarity[] = ['Common', 'Uncommon', 'Rare', 'UltraRare']
const rarityNames: Record<Rarity, string> = { Common: 'Comum', Uncommon: 'Incomum', Rare: 'Rara', UltraRare: 'Ultra rara' }

export function CollectionPage() {
  const [collection, setCollection] = useState<CollectionResponse | null>(null)
  const [expansions, setExpansions] = useState<Expansion[]>([])
  const [name, setName] = useState('')
  const [rarity, setRarity] = useState('')
  const [expansion, setExpansion] = useState('')
  const [onlyOwned, setOnlyOwned] = useState(false)
  const [limit, setLimit] = useState(24)
  const [error, setError] = useState('')

  useEffect(() => {
    let active = true
    api.expansions().then((result) => { if (active) setExpansions(result.expansions) })
      .catch((failure) => { if (active) setError(friendlyError(failure)) })
    return () => { active = false }
  }, [])

  useEffect(() => {
    let active = true
    const timer = window.setTimeout(() => {
      api.collection({ name: name.trim(), rarity, expansion }).then((result) => {
        if (active) { setCollection(result); setError('') }
      }).catch((failure) => { if (active) setError(friendlyError(failure)) })
    }, name ? 250 : 0)
    return () => { active = false; window.clearTimeout(timer) }
  }, [name, rarity, expansion])

  const names = new Map(expansions.map((item) => [item.id, item.name]))
  const visible = collection?.cards.filter((entry) => !onlyOwned || entry.owned) ?? []
  const changeFilter = (setter: (value: string) => void, value: string) => { setter(value); setLimit(24) }

  return <div className="page"><div className="page-heading"><div><span className="eyebrow">SUA BIBLIOTECA DIGITAL</span><h1>Minha coleção</h1><p>Explore o catálogo completo e acompanhe as cartas que já encontrou.</p></div><span className="counter-pill"><LibraryBig size={18} />{collection?.uniqueOwned ?? '—'} únicas</span></div>
    {error && <Feedback message={error} />}
    <div className="filter-bar panel"><div className="search-field"><Search size={19} /><input aria-label="Buscar carta pelo nome" placeholder="Buscar carta pelo nome..." value={name} onChange={(e) => changeFilter(setName, e.target.value)} /></div>
      <div className="filter-bar__select"><SlidersHorizontal size={18} /><select aria-label="Filtrar por raridade" value={rarity} onChange={(e) => changeFilter(setRarity, e.target.value)}><option value="">Todas as raridades</option>{rarities.map((item) => <option key={item} value={item}>{rarityNames[item]}</option>)}</select></div>
      <select aria-label="Filtrar por expansão" value={expansion} onChange={(e) => changeFilter(setExpansion, e.target.value)}><option value="">Todas as expansões</option>{expansions.map((item) => <option key={item.id} value={item.externalId}>{item.name}</option>)}</select>
    </div>
    <div className="collection-toolbar"><span>{visible.length} {visible.length === 1 ? 'carta encontrada' : 'cartas encontradas'} · {collection?.totalCatalog ?? '—'} no catálogo</span><label className="toggle"><input type="checkbox" checked={onlyOwned} onChange={(e) => { setOnlyOwned(e.target.checked); setLimit(24) }} /><span>Somente adquiridas</span></label></div>
    {collection && visible.length === 0 && <div className="empty-state"><LibraryBig size={32} /><h2>Nenhuma carta encontrada</h2><p>Experimente outros filtros ou abra um booster para ampliar sua coleção.</p></div>}
    {!collection && !error && <p className="muted">Carregando o catálogo...</p>}
    <div className="cards-grid">{visible.slice(0, limit).map((entry) => <OwnedCardTile key={entry.card.externalId} entry={entry} expansionName={names.get(entry.card.expansionId)} />)}</div>
    {visible.length > limit && <button className="button button--outline load-more" onClick={() => setLimit(limit + 24)}>Mostrar mais cartas</button>}
  </div>
}
