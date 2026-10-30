import React from 'react';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { Box, createStyles, Group } from '@mantine/core';
import ReactMarkdown from 'react-markdown';
import ScaleFade from '../../transitions/ScaleFade';
import remarkGfm from 'remark-gfm';
import type { TextUiPosition, TextUiProps } from '../../typings';
import MarkdownComponents from '../../config/MarkdownComponents';
import LibIcon from '../../components/LibIcon';
import { Keycap } from '../../components/KeyHints';
import { displayFontFamily } from '../../theme';
import { isEnvBrowser } from '../../utils/misc';

const ROW_HEIGHT = 34;
const KEY_WIDTH = 30;
// Options shown above and below the fixed key row in scroll mode
const VISIBLE_SIDE = 2;

const useStyles = createStyles((theme, params: { position?: TextUiPosition }) => ({
  wrapper: {
    height: '100%',
    width: '100%',
    position: 'absolute',
    display: 'flex',
    alignItems:
      params.position === 'top-center' ? 'baseline' : params.position === 'bottom-center' ? 'flex-end' : 'center',
    justifyContent:
      params.position === 'right-center' ? 'flex-end' : params.position === 'left-center' ? 'flex-start' : 'center',
  },
  container: {
    padding: 12,
    margin: 8,
    fontFamily: displayFontFamily,
    fontStyle: 'italic',
    fontWeight: 700,
    fontSize: 26,
    lineHeight: 1.15,
    textTransform: 'uppercase',
    color: theme.colors.dark[2],
    textShadow: '1px 1px 4px rgba(0, 0, 0, 0.85)',
    filter: 'drop-shadow(0 1px 4px rgba(0, 0, 0, 0.6))',
  },
  line: {
    display: 'flex',
    alignItems: 'center',
    gap: 12,
    minHeight: ROW_HEIGHT,
  },
  active: {
    color: theme.white,
  },
  carousel: {
    position: 'relative',
    overflow: 'hidden',
    paddingLeft: KEY_WIDTH + 12,
  },
  carouselKey: {
    position: 'absolute',
    left: 0,
    display: 'flex',
    alignItems: 'center',
    height: ROW_HEIGHT,
    zIndex: 1,
  },
  carouselList: {
    transition: 'transform 0.18s ease-out',
  },
  option: {
    display: 'flex',
    alignItems: 'center',
    height: ROW_HEIGHT,
    whiteSpace: 'nowrap',
    color: theme.colors.dark[2],
    transition: 'opacity 0.18s ease-out, color 0.18s ease-out',
  },
  text: {
    '& p': { margin: 0 },
  },
}));

// Text is split into lines; a leading `[E]` is drawn as a keycap
const KEY_PATTERN = /^\s*\[([^\]]{1,6})\]\s*(?:[-–—:]\s*)?/;

const TextUI: React.FC = () => {
  const [data, setData] = React.useState<TextUiProps>({
    text: '',
    position: 'right-center',
  });
  const [visible, setVisible] = React.useState(false);
  const [selected, setSelected] = React.useState(0);
  const { classes, cx } = useStyles({ position: data.position });

  const lines = data.text.split(/\n+/).filter((line) => line.trim() !== '');
  const current = Math.min(Math.max(selected, 0), Math.max(lines.length - 1, 0));
  // A single option has nothing to scroll past, so only the key row is shown
  const side = lines.length > 1 ? VISIBLE_SIDE : 0;

  useNuiEvent<TextUiProps>('textUi', (data) => {
    if (!data.position) data.position = 'right-center'; // Default right position
    setData(data);
    setSelected(0);
    setVisible(true);
  });

  useNuiEvent('textUiHide', () => setVisible(false));

  // Selected option in scroll mode, sent by the game (0-based)
  useNuiEvent<number>('textUiSelect', (index) => setSelected(index));

  // Mouse wheel scrolling for the browser preview; in game the scroll input is read from Lua
  React.useEffect(() => {
    if (!visible || !data.scroll || !isEnvBrowser()) return;

    const onWheel = (e: WheelEvent) => {
      const step = e.deltaY > 0 ? 1 : -1;
      setSelected((prev) => (prev + step + lines.length) % lines.length);
    };

    window.addEventListener('wheel', onWheel);
    return () => window.removeEventListener('wheel', onWheel);
  }, [visible, data.scroll, lines.length]);

  return (
    <>
      <Box className={classes.wrapper}>
        <ScaleFade visible={visible}>
          <Box style={data.style} className={classes.container}>
            <Group spacing={12} noWrap align={!data.alignIcon || data.alignIcon === 'center' ? 'center' : 'flex-start'}>
              {data.icon && (
                <LibIcon
                  icon={data.icon}
                  fixedWidth
                  size="lg"
                  animation={data.iconAnimation}
                  style={{ color: data.iconColor }}
                />
              )}
              {data.scroll ? (
                <Box className={classes.carousel} style={{ height: (side * 2 + 1) * ROW_HEIGHT }}>
                  <Box className={classes.carouselKey} style={{ top: side * ROW_HEIGHT }}>
                    <Keycap value={(data.key || 'E').toUpperCase()} />
                  </Box>
                  <Box
                    className={classes.carouselList}
                    style={{ transform: `translateY(${(side - current) * ROW_HEIGHT}px)` }}
                  >
                    {lines.map((line, index) => {
                      const distance = Math.abs(index - current);

                      return (
                        <Box
                          key={`${index}-${line}`}
                          className={cx(classes.option, distance === 0 && classes.active)}
                          style={{ opacity: distance === 0 ? 1 : distance === 1 ? 0.6 : 0.3 }}
                        >
                          <ReactMarkdown
                            components={MarkdownComponents}
                            remarkPlugins={[remarkGfm]}
                            className={classes.text}
                          >
                            {line}
                          </ReactMarkdown>
                        </Box>
                      );
                    })}
                  </Box>
                </Box>
              ) : (
                <Box>
                  {lines.map((line, index) => {
                    const match = line.match(KEY_PATTERN);
                    const body = match ? line.slice(match[0].length) : line;

                    return (
                      <Box key={`${index}-${line}`} className={cx(classes.line, index === 0 && classes.active)}>
                        {match && <Keycap value={match[1].toUpperCase()} />}
                        <ReactMarkdown
                          components={MarkdownComponents}
                          remarkPlugins={[remarkGfm]}
                          className={classes.text}
                        >
                          {body}
                        </ReactMarkdown>
                      </Box>
                    );
                  })}
                </Box>
              )}
            </Group>
          </Box>
        </ScaleFade>
      </Box>
    </>
  );
};

export default TextUI;
