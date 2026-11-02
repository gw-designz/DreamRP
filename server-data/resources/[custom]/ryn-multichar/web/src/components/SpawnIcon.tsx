import {
  BriefcaseIcon,
  Building2Icon,
  CrossIcon,
  HistoryIcon,
  HomeIcon,
  LayersIcon,
  MapPinIcon,
  PlaneIcon,
  ShieldIcon,
  TrainFrontIcon,
  type LucideIcon,
} from 'lucide-react'

const icons: Record<string, LucideIcon> = {
  'map-pin': MapPinIcon,
  home: HomeIcon,
  history: HistoryIcon,
  shield: ShieldIcon,
  building: Building2Icon,
  apartment: Building2Icon,
  plane: PlaneIcon,
  airport: PlaneIcon,
  train: TrainFrontIcon,
  hospital: CrossIcon,
  medical: CrossIcon,
  briefcase: BriefcaseIcon,
  job: BriefcaseIcon,
  layers: LayersIcon,
}

export function SpawnIcon({ icon, className }: { icon?: string; className?: string }) {
  const Icon = (icon && icons[icon]) || MapPinIcon
  return <Icon className={className} strokeWidth={2.25} aria-hidden />
}
