import { useLocale } from '@/hooks/useLocale'
import { cn } from '@/lib/utils'

interface BrandMarkProps {
  logo?: string
  serverName?: string
}

/** Server logo, or its initial when no logo is configured. */
export function BrandMark({ logo, serverName }: BrandMarkProps) {
  const { t } = useLocale()
  const name = (serverName ?? '').trim() || t('brand')

  if (logo) return <img src={logo} alt={name} className="ryn-brand-logo" />
  return (
    <span className="ryn-brand-mark" aria-label={name}>
      {name.charAt(0).toUpperCase()}
    </span>
  )
}

interface SelectHeaderProps extends BrandMarkProps {
  tip?: string
  hidden?: boolean
}

export function SelectHeader({ logo, serverName, hidden = false }: SelectHeaderProps) {
  return (
    <header className={cn('ryn-select-header', hidden && 'ryn-select-header--hidden')} data-animate="chrome">
      <BrandMark logo={logo} serverName={serverName} />
    </header>
  )
}
