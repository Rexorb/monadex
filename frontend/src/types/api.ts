export type Rarity = 'Common' | 'Uncommon' | 'Rare' | 'UltraRare'

export interface Card {
  externalId: string
  name: string
  expansionId: number
  number: string
  rarity: Rarity
  originalRarity: string | null
  imageUrl: string | null
  pokemon: string | null
}

export interface OwnedCard {
  card: Card
  quantity: number
  owned: boolean
}

export interface Dashboard {
  username: string
  boosters: number
  totalCards: number
  uniqueCards: number
  byRarity: Record<Rarity, number>
  catalogTotal: number
  progressPercent: number
  dailyReward: { date: string; claimed: boolean }
}

export interface Expansion {
  id: number
  externalId: string
  name: string
  logoUrl: string | null
  releaseDate: string | null
  totalCards: number
  uniqueOwned: number
  progressPercent: number
}

export interface ExpansionDetail {
  expansion: Expansion
  cards: OwnedCard[]
}

export interface CollectionResponse {
  totalCatalog: number
  uniqueOwned: number
  cards: OwnedCard[]
}

export interface DailyClaim {
  date: string
  claimed: boolean
  grantedNow: boolean
  boosters: number
}
