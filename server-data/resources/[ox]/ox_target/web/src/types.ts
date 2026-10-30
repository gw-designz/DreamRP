export interface TargetOption {
  label: string;
  icon?: string;
  iconColor?: string;
  hide?: boolean;
  resource?: string;
  [key: string]: unknown;
}

export interface TargetData {
  options?: Record<string, TargetOption[]>;
  zones?: TargetOption[][];
}

export interface TargetItem {
  data: TargetOption;
  targetType: string;
  targetId: number;
  zoneId: number | null;
}

export type Direction = 'top' | 'bottom' | 'left' | 'right';

export interface PlacedItem {
  angle: number;
  angleOffset: number;
  item: TargetItem;
  dir: Direction;
}
