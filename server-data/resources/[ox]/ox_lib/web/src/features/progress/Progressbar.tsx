import React from 'react';
import { Box, createStyles, Text } from '@mantine/core';
import type { IconProp } from '@fortawesome/fontawesome-svg-core';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { fetchNui } from '../../utils/fetchNui';
import ScaleFade from '../../transitions/ScaleFade';
import type { ProgressbarProps } from '../../typings';
import { fontFamily } from '../../theme';
import { Keycap } from '../../components/KeyHints';
import LibIcon from '../../components/LibIcon';
import { useLocales } from '../../providers/LocaleProvider';

const blue = '#2f8fff';

const useStyles = createStyles((theme) => ({
  wrapper: {
    width: '100%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    bottom: 60,
    position: 'absolute',
  },
  container: {
    width: 480,
    display: 'flex',
    alignItems: 'center',
    gap: 22,
    filter: 'drop-shadow(0 1px 4px rgba(0, 0, 0, 0.7))',
  },
  // blue-edged diamond holding the icon
  badge: {
    flexShrink: 0,
    width: 48,
    height: 48,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 6,
    transform: 'rotate(45deg)',
    border: `2px solid ${blue}`,
    borderRadius: 7,
    backgroundColor: 'rgba(10, 18, 30, 0.85)',
    boxShadow: `0 0 8px rgba(47, 143, 255, 0.35)`,
  },
  badgeIcon: {
    transform: 'rotate(-45deg)',
    fontSize: 20,
    color: blue,
  },
  body: {
    flex: 1,
    minWidth: 0,
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 9,
    gap: 16,
    fontFamily,
    fontWeight: 700,
    color: theme.white,
  },
  label: {
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap',
    fontFamily,
    fontWeight: 700,
    fontSize: 21,
    lineHeight: 1,
    color: theme.white,
  },
  right: {
    display: 'flex',
    alignItems: 'center',
    gap: 14,
    flexShrink: 0,
  },
  cancel: {
    display: 'flex',
    alignItems: 'center',
    gap: 8,
    fontSize: 14,
    textTransform: 'uppercase',
    opacity: 0.8,
  },
  percent: {
    fontSize: 19,
    lineHeight: 1,
    fontVariantNumeric: 'tabular-nums',
  },
  track: {
    width: '100%',
    height: 12,
    overflow: 'hidden',
    borderRadius: 3,
    border: '1px solid rgba(47, 143, 255, 0.45)',
    backgroundColor: 'rgba(28, 74, 120, 0.55)',
  },
  bar: {
    height: '100%',
    borderRadius: 2,
    backgroundColor: blue,
    boxShadow: `0 0 6px rgba(47, 143, 255, 0.6)`,
  },
}));

const Progressbar: React.FC = () => {
  const { classes } = useStyles();
  const { locale } = useLocales();
  const [visible, setVisible] = React.useState(false);
  const [label, setLabel] = React.useState('');
  const [icon, setIcon] = React.useState<string>('hand');
  const [duration, setDuration] = React.useState(0);
  const [canCancel, setCanCancel] = React.useState(false);
  const [percent, setPercent] = React.useState(0);
  const [startedAt, setStartedAt] = React.useState(0);

  useNuiEvent('progressCancel', () => setVisible(false));

  useNuiEvent<ProgressbarProps>('progress', (data) => {
    setVisible(true);
    setLabel(data.label);
    setIcon(data.icon || 'hand');
    setDuration(data.duration);
    setCanCancel(!!data.canCancel);
    setPercent(0);
    setStartedAt(performance.now());
  });

  // the bar itself runs on a CSS animation; this only drives the number
  React.useEffect(() => {
    if (!visible || duration <= 0) return;

    let frame = 0;
    const tick = (now: number) => {
      const value = Math.min(100, Math.floor(((now - startedAt) / duration) * 100));
      setPercent(value);
      if (value < 100) frame = requestAnimationFrame(tick);
    };

    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [visible, duration, startedAt]);

  return (
    <>
      <Box className={classes.wrapper}>
        <ScaleFade visible={visible} onExitComplete={() => fetchNui('progressComplete')}>
          <Box className={classes.container}>
            <Box className={classes.badge}>
              <LibIcon icon={icon as IconProp} className={classes.badgeIcon} fixedWidth />
            </Box>
            <Box className={classes.body}>
              <Box className={classes.header}>
                <Text className={classes.label}>{label}</Text>
                <Box className={classes.right}>
                  {canCancel && (
                    <Box className={classes.cancel}>
                      <Keycap value="X" />
                      {locale.ui.cancel}
                    </Box>
                  )}
                  <span className={classes.percent}>{percent}%</span>
                </Box>
              </Box>
              <Box className={classes.track}>
                <Box
                  key={startedAt}
                  className={classes.bar}
                  onAnimationEnd={() => setVisible(false)}
                  sx={{
                    animation: 'progress-bar linear',
                    animationDuration: `${duration}ms`,
                  }}
                />
              </Box>
            </Box>
          </Box>
        </ScaleFade>
      </Box>
    </>
  );
};

export default Progressbar;
