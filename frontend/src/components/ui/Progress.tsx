export function Progress({ value, label }: { value: number; label?: string }) {
  const safe = Math.min(100, Math.max(0, value))
  return <div className="progress" aria-label={label ?? 'Progresso'}>
    <div className="progress__track" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(safe)}>
      <span style={{ width: `${safe}%` }} />
    </div>
    <span className="progress__value">{safe.toFixed(1).replace('.', ',')}%</span>
  </div>
}
