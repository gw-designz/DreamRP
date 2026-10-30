import { useEffect, useMemo, useState } from 'react';
import type { CSSProperties } from 'react';
import { motion } from 'framer-motion';
import { cn } from './cn';
import { fetchNui } from './fetchNui';
import { useTargetStore } from './store';
import { ROW_SPACING, flattenTarget, placeItems, radiusFor, remSize } from './layout';
import type { Direction, TargetItem } from './types';

const SPRING = { type: 'spring', stiffness: 500, damping: 30 } as const;

/** 1x1 transparent png - the interface draws its own reticle instead. */
const BLANK_CURSOR =
  'url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z/C/HgAGgwJ/lK3Q6wAAAABJRU5ErkJggg==), auto';

const ALL_CORNERS = 'clip-topLeftTopRightBottomLeftBottomRight';

interface OptionProps {
  option: TargetItem;
  dir: Direction;
  relativeAngle: number;
  hovered: boolean;
}

const Option = ({ option, dir, relativeAngle, hovered }: OptionProps) => (
  <div
    className={cn(
      'position relative whitespace-nowrap text-white font-qt isolate px-6 py-2 min-w-48 flex justify-center items-center gap-4 select-none'
    )}
    style={
      {
        '--targetX': `${((1 - Math.cos(relativeAngle)) / 2) * 100}%`,
        '--targetY': `${((1 - Math.sin(relativeAngle)) / 2) * 100}%`,
      } as CSSProperties
    }
  >
    <motion.div
      layout="size"
      className={cn(
        'absolute w-full h-full top-0 left-0 clip z-[-1] clip',
        `target target-${dir}`,
        hovered && 'hovered'
      )}
    />
    <motion.div
      layout="size"
      className={cn(
        'absolute w-full h-full top-0 left-0 clip z-[-1] clip-border',
        `target-border target-${dir}`,
        hovered && 'hovered'
      )}
    />
    {option.data.label}
  </div>
);

export const Target = () => {
  const rem = remSize();
  const target = useTargetStore((state) => state.target);
  const startCoords = useTargetStore((state) => state.startCoords);
  const hasCursor = useTargetStore((state) => state.hasCursor);

  const [origin, setOrigin] = useState({ x: 0.5, y: 0.5 });
  const [pointerAngle, setPointerAngle] = useState(-Math.PI / 4);
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);

  const items = useMemo(() => flattenTarget(target), [target]);

  const radius = radiusFor(items.length);
  const perSide = Math.floor((items.length - 1) / 2);

  const placed = useMemo(() => placeItems(items), [items]);

  useEffect(() => {
    if (!hasCursor) setOrigin({ x: 0.5, y: 0.5 });

    const onMouseMove = (event: MouseEvent) => {
      const x = event.clientX / window.innerWidth;
      const y = event.clientY / window.innerHeight;
      const angle = Math.atan2(y - origin.y, x - origin.x);

      setPointerAngle(angle);

      let closest: number | null = null;
      let closestDelta = Infinity;

      placed.forEach(({ angle: itemAngle, angleOffset }, index) => {
        const absolute = itemAngle + angleOffset;
        const delta = Math.abs(((absolute - angle + Math.PI) % (2 * Math.PI)) - Math.PI);

        if (delta < Math.PI / 4 && delta < closestDelta) {
          closestDelta = delta;
          closest = index;
        }
      });

      setHoveredIndex(closest);
    };

    window.addEventListener('mousemove', onMouseMove);

    return () => window.removeEventListener('mousemove', onMouseMove);
  }, [origin, hasCursor, placed]);

  useEffect(() => {
    if (!hasCursor) {
      setHoveredIndex(null);
      return;
    }

    const onClick = () => {
      if (hoveredIndex === null) return;

      const entry = placed[hoveredIndex];

      if (entry) fetchNui('select', [entry.item.targetType, entry.item.targetId, entry.item.zoneId]);
    };

    window.addEventListener('click', onClick);

    return () => window.removeEventListener('click', onClick);
  }, [hoveredIndex, hasCursor, placed]);

  const anchor = {
    left: `${startCoords.x * 100}%`,
    top: `${startCoords.y * 100}%`,
    translateX: '-50%',
    translateY: '-50%',
  };

  return (
    <motion.div
      initial={{ scale: 0.8, opacity: 0, ...anchor }}
      animate={{ scale: 1, opacity: 1, ...anchor }}
      exit={{ scale: 0.8, opacity: 0, ...anchor }}
      transition={SPRING}
      className="absolute w-full h-full"
      style={{ cursor: BLANK_CURSOR }}
    >
      <div
        className="absolute top-1/2 left-1/2 w-8 h-8 flex items-center justify-center"
        style={{
          transform: `translate(-50%, -50%) rotate(${pointerAngle + Math.PI / 4}rad)`,
          transformOrigin: 'center',
        }}
      >
        <div
          className={cn('relative inline-flex isolate', 'absolute w-4 h-4 flex items-center justify-center font-qt')}
          style={
            {
              '--dentSize-tl': '0.25rem',
              '--dentSize-tr': '0.25rem',
              '--dentSize-bl': '0.25rem',
              '--dentSize-br': '0.25rem',
              '--clipBorderWidth': '2px',
            } as CSSProperties
          }
        >
          <div
            className={cn(
              'corners-border absolute inset-0 pointer-events-none -z-10 clip-border',
              ALL_CORNERS,
              'transition-colors bg-white/50',
              placed.length > 0 && 'bg-primary'
            )}
          />
        </div>

        {hasCursor && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={SPRING}
            className="absolute w-full h-full top-1/2 left-1/2 image-border"
            style={
              {
                transform: 'translate(-50%, -50%)',
                '--imBorderBg':
                  'radial-gradient(circle at 100% 0%, hsl(var(--primary)), hsl(var(--primary)) 20%, transparent 50%)',
                '--imBorderWidth': '0.125rem',
              } as CSSProperties
            }
          />
        )}
      </div>

      {placed.map(({ angle, item, dir, angleOffset }, index) => {
        const distance = rem * radius;
        const absolute = angle + angleOffset;

        let x = Math.cos(absolute) * distance;
        let y = Math.sin(absolute) * distance;
        let translateX = '-50%';
        let translateY = '-50%';

        if (dir === 'left') translateX = '-100%';
        if (dir === 'right') translateX = '0';
        if (dir === 'top') translateY = '-100%';
        if (dir === 'bottom') translateY = '0';

        if (dir === 'top' || dir === 'bottom') {
          x = 0;
          y = (dir === 'top' ? -1 : 1) * Math.max(perSide / 2, 1) * ROW_SPACING * rem;
        }

        return (
          <motion.div
            key={`${item.data.resource}${item.targetType}${item.targetId}${item.zoneId ?? ''}`}
            initial={{ left: '50%', top: '50%', opacity: 0, translateX, translateY }}
            animate={{
              left: `calc(50% + ${x}px)`,
              top: `calc(50% + ${y}px)`,
              opacity: 1,
              translateX,
              translateY,
            }}
            exit={{ left: '50%', top: '50%', opacity: 0, translateX, translateY }}
            transition={{ ...SPRING, delay: index * 0.03 }}
            className="absolute w-fit"
          >
            <Option option={item} dir={dir} relativeAngle={absolute} hovered={hoveredIndex === index} />
          </motion.div>
        );
      })}
    </motion.div>
  );
};
