import type { PlacedItem, TargetItem } from './types';

/** 1rem in px. Every measurement below is expressed in rem, like the original. */
export function remSize() {
  return parseFloat(getComputedStyle(document.documentElement).fontSize);
}

/** Vertical spacing between two stacked options, in rem. */
export const ROW_SPACING = 3.5;

/** Base radius factor, in rem. */
const BASE_RADIUS = 3;

/** Fan radius in rem for a given option count. */
export function radiusFor(count: number) {
  return BASE_RADIUS + Math.pow(count, 0.75) * (1.625 / 5) * BASE_RADIUS;
}

/**
 * Angles for one side of the fan: `count` rows spaced `ROW_SPACING` apart on a
 * circle of the given radius, mirrored around the horizontal axis.
 */
export function columnAngles(radius: number, count: number): number[] {
  if (count === 0) return [];

  const angles: number[] = [];

  if (count % 2 === 1) {
    angles.push(0);

    for (let i = 1; i <= Math.floor(count / 2); i++) {
      const angle = Math.asin((i * ROW_SPACING) / radius);
      angles.push(angle);
      angles.push(-angle);
    }
  } else {
    for (let i = 0; i < count / 2; i++) {
      const angle = Math.asin(((i + 0.5) * ROW_SPACING) / radius);
      angles.push(angle);
      angles.push(-angle);
    }
  }

  return angles.sort((a, b) => a - b);
}

/**
 * Places every option: first one on top, the rest split into a left and a right
 * column, and - when the remainder is odd - the last one at the bottom.
 */
export function placeItems(items: TargetItem[]): PlacedItem[] {
  if (items.length <= 2) {
    return [
      ...(items[0] ? [{ angle: -Math.PI / 2, item: items[0], dir: 'top' as const, angleOffset: 0 }] : []),
      ...(items[1] ? [{ angle: Math.PI / 2, item: items[1], dir: 'bottom' as const, angleOffset: 0 }] : []),
    ];
  }

  const remaining = items.length - 1;
  const perSide = Math.floor(remaining / 2);
  const radius = radiusFor(items.length);

  const left: number[] = [];
  const right: number[] = [];

  for (let i = 1; i <= 2 * perSide; i++) {
    if (i <= perSide) left.push(i);
    else right.push(i);
  }

  const offsets = columnAngles(radius, perSide);

  return [
    { angle: -Math.PI / 2, item: items[0], dir: 'top', angleOffset: 0 },
    ...left.map((index, i) => ({ angle: Math.PI, angleOffset: offsets[i], item: items[index], dir: 'left' as const })),
    ...right.map((index, i) => ({ angle: 0, angleOffset: offsets[i], item: items[index], dir: 'right' as const })),
    ...(remaining % 2 === 1
      ? [{ angle: Math.PI / 2, item: items[perSide * 2 + 1], dir: 'bottom' as const, angleOffset: 0 }]
      : []),
  ];
}

/** Flattens the payload into a single ordered list, dropping hidden options. */
export function flattenTarget(target: { options?: Record<string, any[]>; zones?: any[][] } | null): TargetItem[] {
  const items: TargetItem[] = [];

  // An empty Lua table serialises to `{}` rather than `[]`, so every list is
  // checked before it is walked.
  if (target?.options) {
    for (const targetType in target.options) {
      const group = target.options[targetType];
      if (!Array.isArray(group)) continue;

      group.forEach((data, index) => {
        items.push({ data, targetType, targetId: index + 1, zoneId: null });
      });
    }
  }

  if (Array.isArray(target?.zones)) {
    for (let zone = 0; zone < target.zones.length; zone++) {
      const group = target.zones[zone];
      if (!Array.isArray(group)) continue;

      group.forEach((data, index) => {
        items.push({ data, targetType: 'zones', targetId: index + 1, zoneId: zone + 1 });
      });
    }
  }

  return items.filter((item) => !item.data.hide);
}
