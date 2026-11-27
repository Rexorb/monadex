import type { Card, CollectionResponse, DailyClaim, Dashboard, Expansion, ExpansionDetail } from '../types/api'

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message)
    this.name = 'ApiError'
  }
}

const errorMessages: Record<string, string> = {
  InvalidUsername: 'Use de 3 a 32 caracteres: letras, números ou _.',
  InvalidPassword: 'A senha precisa ter entre 12 e 1024 caracteres.',
  PasswordMismatch: 'As senhas não conferem.',
  UsernameTaken: 'Esse nome de usuário já está em uso.',
  InsufficientBoosters: 'Você não tem boosters disponíveis no momento.',
  InvalidPlayerState: 'Não foi possível atualizar seu inventário. Tente novamente.',
  EmptyCardPool: 'O catálogo ainda não está completo para abrir boosters.',
  'Invalid credentials': 'Usuário ou senha incorretos.',
  'Authentication required': 'Sua sessão terminou. Entre novamente.',
  Forbidden: 'Não foi possível validar a sessão. Atualize a página e tente novamente.',
  'Invalid request': 'Confira os dados enviados e tente novamente.',
  'Not found': 'O conteúdo solicitado não foi encontrado.',
  'Internal server error': 'O servidor encontrou um problema. Tente novamente.',
}

let csrfToken: string | null = null

export function clearCsrf() {
  csrfToken = null
}

export function friendlyError(error: unknown): string {
  if (error instanceof ApiError) return error.message
  return 'Não foi possível completar a operação. Confira sua conexão e tente novamente.'
}

async function request<T>(path: string, options: RequestInit = {}, retryCsrf = true): Promise<T> {
  const method = options.method?.toUpperCase() ?? 'GET'
  const headers = new Headers(options.headers)
  if (options.body !== undefined) headers.set('Content-Type', 'application/json')
  if (method === 'POST' && path !== '/auth/csrf') {
    if (!csrfToken) await getCsrf()
    headers.set('X-XSRF-TOKEN', csrfToken ?? '')
  }

  let response: Response
  try {
    response = await fetch(`/api${path}`, { ...options, method, headers, credentials: 'include' })
  } catch {
    throw new ApiError(0, 'Não foi possível conectar ao servidor. Confirme se o backend está em execução.')
  }

  if (response.status === 403 && method === 'POST' && retryCsrf) {
    clearCsrf()
    await getCsrf()
    return request<T>(path, options, false)
  }

  const payload: unknown = await response.json().catch(() => null)
  if (!response.ok) {
    const error = typeof payload === 'object' && payload !== null && 'error' in payload
      ? String(payload.error) : ''
    throw new ApiError(response.status, errorMessages[error] ??
      ({ 400: 'Requisição inválida.', 401: 'Sua sessão terminou. Entre novamente.',
        403: 'Acesso não autorizado.', 404: 'Não encontrado.', 409: 'Não foi possível concluir esta operação.',
        500: 'O servidor encontrou um problema.' }[response.status] ?? `Erro ${response.status}.`))
  }
  return payload as T
}

export async function getCsrf() {
  const result = await request<{ csrfToken: string }>('/auth/csrf')
  csrfToken = result.csrfToken
  return csrfToken
}

export const api = {
  dashboard: () => request<Dashboard>('/dashboard'),
  register: (username: string, password: string, confirmation: string) =>
    request<{ username: string }>('/register', { method: 'POST', body: JSON.stringify({ username, password, confirmation }) }),
  login: (username: string, password: string) =>
    request<{ username: string }>('/login', { method: 'POST', body: JSON.stringify({ username, password }) }),
  logout: () => request<{ loggedOut: boolean }>('/logout', { method: 'POST' }),
  claim: () => request<DailyClaim>('/rewards/daily/claim', { method: 'POST' }),
  boosters: () => request<{ available: number }>('/boosters'),
  open: () => request<{ cards: Card[] }>('/boosters/open', { method: 'POST' }),
  last: () => request<{ cards: Card[] }>('/boosters/last'),
  collection: (filters: { rarity?: string; expansion?: string; name?: string }) => {
    const params = new URLSearchParams()
    for (const [key, value] of Object.entries(filters)) if (value) params.set(key, value)
    return request<CollectionResponse>(`/collection${params.size ? `?${params}` : ''}`)
  },
  expansions: () => request<{ expansions: Expansion[] }>('/expansions'),
  expansion: (id: number) => request<ExpansionDetail>(`/expansions/${id}`),
}
