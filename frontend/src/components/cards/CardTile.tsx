import { useState } from 'react'
import { ImageOff } from 'lucide-react'
import type { Card, OwnedCard } from '../../types/api'

export const rarityLabels: Record<Card['rarity'], string> = {
  Common: 'Comum', Uncommon: 'Incomum', Rare: 'Rara', UltraRare: 'Ultra rara',
}

export function CardTile({ card, quantity, owned = true, expansionName }: {
  card: Card; quantity?: number; owned?: boolean; expansionName?: string
}) {
  const [imageFailed, setImageFailed] = useState(false)
  const source = card.imageUrl && (card.imageUrl.endsWith('.webp') || card.imageUrl.endsWith('.png')
    ? card.imageUrl : `${card.imageUrl.replace(/\/$/, '')}/high.webp`)
  return <article className={`card-tile rarity-${card.rarity.toLowerCase()} ${!owned ? 'card-tile--locked' : ''}`}>
    <div className="card-tile__art">
      {source && !imageFailed
        ? <img src={source} alt={`Carta ${card.name}`} loading="lazy" onError={() => setImageFailed(true)} />
        : <div className="card-tile__placeholder"><ImageOff size={34} /><span>Imagem indisponível</span></div>}
      {!owned && <span className="card-tile__unowned">Não adquirida</span>}
      {quantity !== undefined && quantity > 0 && <span className="card-tile__quantity">×{quantity}</span>}
    </div>
    <div className="card-tile__info">
      <span className="card-tile__eyebrow">{expansionName ?? `Carta #${card.number}`}</span>
      <h3 title={card.name}>{card.name}</h3>
      <span className="rarity-badge">{rarityLabels[card.rarity]}</span>
    </div>
  </article>
}

export function OwnedCardTile({ entry, expansionName }: { entry: OwnedCard; expansionName?: string }) {
  return <CardTile card={entry.card} quantity={entry.quantity} owned={entry.owned} expansionName={expansionName} />
}
