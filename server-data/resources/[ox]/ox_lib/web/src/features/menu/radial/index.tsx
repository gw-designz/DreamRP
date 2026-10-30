import { Box, createStyles } from '@mantine/core';
import { useEffect, useState } from 'react';
import { IconProp } from '@fortawesome/fontawesome-svg-core';
import { useNuiEvent } from '../../../hooks/useNuiEvent';
import { fetchNui } from '../../../utils/fetchNui';
import { isIconUrl } from '../../../utils/isIconUrl';
import ScaleFade from '../../../transitions/ScaleFade';
import type { RadialMenuItem } from '../../../typings';
import { useLocales } from '../../../providers/LocaleProvider';
import LibIcon from '../../../components/LibIcon';
import KeyHints from '../../../components/KeyHints';
import { displayFontFamily } from '../../../theme';

const OUTER_RADIUS = 168;
const INNER_RADIUS = 62;

const useStyles = createStyles((theme) => ({
  wrapper: {
    position: 'absolute',
    top: '50%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
  },
  outerRing: {
    fill: 'none',
    stroke: 'rgba(255, 255, 255, 0.92)',
    strokeWidth: 3,
  },
  outerRingShadow: {
    fill: 'none',
    stroke: 'rgba(11, 15, 22, 0.85)',
    strokeWidth: 16,
  },
  sector: {
    fill: 'rgba(21, 30, 44, 0.82)',
    color: theme.white,

    '&:hover': {
      fill: theme.white,
      cursor: 'pointer',
      color: theme.colors.dark[8],
      '> g > text, > g > svg > path': {
        fill: theme.colors.dark[8],
      },
    },
    '> g > text': {
      fill: theme.white,
      strokeWidth: 0,
      fontFamily: displayFontFamily,
      fontWeight: 700,
      textTransform: 'uppercase',
    },
  },
  centerCircle: {
    fill: 'rgba(11, 15, 22, 0.45)',
    stroke: theme.white,
    strokeWidth: 3,
    '&:hover': {
      cursor: 'pointer',
      fill: 'rgba(255, 255, 255, 0.18)',
    },
  },
  centerLabel: {
    position: 'absolute',
    top: '50%',
    left: '50%',
    transform: 'translate(-50%, -50%)',
    pointerEvents: 'none',
    fontFamily: displayFontFamily,
    fontWeight: 700,
    fontSize: 30,
    textTransform: 'uppercase',
    color: theme.white,
    textShadow: '1px 1px 4px rgba(0, 0, 0, 0.8)',
  },
  hints: {
    position: 'absolute',
    top: 'calc(100% + 28px)',
    left: '50%',
    transform: 'translateX(-50%)',
  },
}));

const calculateFontSize = (text: string): number => {
  if (text.length > 20) return 12;
  if (text.length > 15) return 13;
  return 15;
};

const splitTextIntoLines = (text: string, maxCharPerLine: number = 15): string[] => {
  const words = text.split(' ');
  const lines: string[] = [];
  let currentLine = words[0];

  for (let i = 1; i < words.length; i++) {
    if (currentLine.length + words[i].length + 1 <= maxCharPerLine) {
      currentLine += ' ' + words[i];
    } else {
      lines.push(currentLine);
      currentLine = words[i];
    }
  }
  lines.push(currentLine);
  return lines;
};

const PAGE_ITEMS = 6;

const degToRad = (deg: number) => deg * (Math.PI / 180);

const RadialMenu: React.FC = () => {
  const { classes } = useStyles();
  const { locale } = useLocales();
  const newDimension = 350 * 1.1025;
  const [visible, setVisible] = useState(false);
  const [menuItems, setMenuItems] = useState<RadialMenuItem[]>([]);
  const [menu, setMenu] = useState<{ items: RadialMenuItem[]; sub?: boolean; page: number }>({
    items: [],
    sub: false,
    page: 1,
  });

  const changePage = async (increment?: boolean) => {
    setVisible(false);

    const didTransition: boolean = await fetchNui('radialTransition');

    if (!didTransition) return;

    setVisible(true);
    setMenu({ ...menu, page: increment ? menu.page + 1 : menu.page - 1 });
  };

  useEffect(() => {
    if (menu.items.length <= PAGE_ITEMS) return setMenuItems(menu.items);
    const items = menu.items.slice(
      PAGE_ITEMS * (menu.page - 1) - (menu.page - 1),
      PAGE_ITEMS * menu.page - menu.page + 1
    );
    if (PAGE_ITEMS * menu.page - menu.page + 1 < menu.items.length) {
      items[items.length - 1] = { icon: 'ellipsis-h', label: locale.ui.more, isMore: true };
    }
    setMenuItems(items);
  }, [menu.items, menu.page]);

  useNuiEvent('openRadialMenu', async (data: { items: RadialMenuItem[]; sub?: boolean; option?: string } | false) => {
    if (!data) return setVisible(false);
    let initialPage = 1;
    if (data.option) {
      data.items.findIndex(
        (item, index) => item.menu == data.option && (initialPage = Math.floor(index / PAGE_ITEMS) + 1)
      );
    }
    setMenu({ ...data, page: initialPage });
    setVisible(true);
  });

  useNuiEvent('refreshItems', (data: RadialMenuItem[]) => {
    setMenu({ ...menu, items: data });
  });

  return (
    <>
      <Box
        className={classes.wrapper}
        onContextMenu={async () => {
          if (menu.page > 1) await changePage();
          else if (menu.sub) fetchNui('radialBack');
        }}
      >
        <ScaleFade visible={visible}>
          <svg
            style={{ overflow: 'visible' }}
            width={`${newDimension}px`}
            height={`${newDimension}px`}
            viewBox="0 0 350 350"
            transform="rotate(90)"
          >
            <g transform="translate(175, 175)">
              <circle r={OUTER_RADIUS + 5} className={classes.outerRingShadow} />
              <circle r={OUTER_RADIUS + 5} className={classes.outerRing} />
            </g>
            {menuItems.map((item, index) => {
              const pieAngle = 360 / (menuItems.length < 3 ? 3 : menuItems.length);
              const angle = degToRad(pieAngle / 2 + 90);
              const gap = 1;
              const radius = (OUTER_RADIUS + INNER_RADIUS) / 2 - gap;
              const sinAngle = Math.sin(angle);
              const cosAngle = Math.cos(angle);
              const iconYOffset = splitTextIntoLines(item.label, 15).length > 3 ? 3 : 0;
              const iconX = 175 + sinAngle * radius;
              const iconY = 175 + cosAngle * radius + iconYOffset; // Apply the Y offset to iconY
              const iconWidth = Math.min(Math.max(item.iconWidth || 50, 0), 100);
              const iconHeight = Math.min(Math.max(item.iconHeight || 50, 0), 100);

              return (
                <g
                  key={`radial-${menu.page}-${index}`}
                  transform={`rotate(-${index * pieAngle} 175 175) translate(${sinAngle * gap}, ${cosAngle * gap})`}
                  className={classes.sector}
                  onClick={async () => {
                    const clickIndex = menu.page === 1 ? index : PAGE_ITEMS * (menu.page - 1) - (menu.page - 1) + index;
                    if (!item.isMore) fetchNui('radialClick', clickIndex);
                    else {
                      await changePage(true);
                    }
                  }}
                >
                  <path
                    d={`M${175 + OUTER_RADIUS - gap},175 A${OUTER_RADIUS - gap},${OUTER_RADIUS - gap} 0 0,0 ${
                      175 + (OUTER_RADIUS - gap) * Math.cos(degToRad(pieAngle))
                    },${175 - (OUTER_RADIUS - gap) * Math.sin(degToRad(pieAngle))} L${
                      175 + INNER_RADIUS * Math.cos(degToRad(pieAngle))
                    },${175 - INNER_RADIUS * Math.sin(degToRad(pieAngle))} A${INNER_RADIUS},${INNER_RADIUS} 0 0,1 ${
                      175 + INNER_RADIUS
                    },175 Z`}
                  />
                  <g transform={`rotate(${index * pieAngle - 90} ${iconX} ${iconY})`} pointerEvents="none">
                    {typeof item.icon === 'string' && isIconUrl(item.icon) ? (
                      <image
                        href={item.icon}
                        width={iconWidth}
                        height={iconHeight}
                        x={iconX - iconWidth / 2}
                        y={iconY - iconHeight / 2 - iconHeight / 4}
                      />
                    ) : (
                      <LibIcon
                        x={iconX - 14.5}
                        y={iconY - 17.5}
                        icon={item.icon as IconProp}
                        width={30}
                        height={30}
                        fixedWidth
                      />
                    )}
                    <text
                      x={iconX}
                      y={iconY + (splitTextIntoLines(item.label, 15).length > 2 ? 15 : 28)}
                      fill="#fff"
                      textAnchor="middle"
                      fontSize={calculateFontSize(item.label)}
                      pointerEvents="none"
                      lengthAdjust="spacingAndGlyphs"
                    >
                      {splitTextIntoLines(item.label, 15).map((line, index) => (
                        <tspan x={iconX} dy={index === 0 ? 0 : '1.2em'} key={index}>
                          {line}
                        </tspan>
                      ))}
                    </text>
                  </g>
                </g>
              );
            })}
            <g
              transform={`translate(175, 175)`}
              onClick={async () => {
                if (menu.page > 1) await changePage();
                else {
                  if (menu.sub) fetchNui('radialBack');
                  else {
                    setVisible(false);
                    fetchNui('radialClose');
                  }
                }
              }}
            >
              <circle r={INNER_RADIUS - 6} className={classes.centerCircle} />
            </g>
          </svg>
          <div className={classes.centerLabel}>
            {menu.page > 1 || menu.sub ? locale.ui.back || 'Back' : locale.ui.menu || 'Menu'}
          </div>
          <KeyHints
            className={classes.hints}
            hints={[
              { key: 'mouse', label: locale.ui.select || 'Select' },
              { key: 'mouse', label: menu.page > 1 || menu.sub ? locale.ui.back || 'Back' : locale.ui.close },
            ]}
          />
        </ScaleFade>
      </Box>
    </>
  );
};

export default RadialMenu;
