import { AlertCircle, CircleCheck } from 'lucide-react'

export function Feedback({ message, kind = 'error' }: { message: string; kind?: 'error' | 'success' }) {
  return <p className={`feedback feedback--${kind}`} role={kind === 'error' ? 'alert' : 'status'}>
    {kind === 'error' ? <AlertCircle size={18} /> : <CircleCheck size={18} />}{message}
  </p>
}
