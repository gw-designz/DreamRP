import { useNuiEvent } from '../../../hooks/useNuiEvent';
import { Box, createStyles, Flex, Stack, Text } from '@mantine/core';
import { useEffect, useState } from 'react';
import { ContextMenuProps } from '../../../typings';
import ContextButton from './components/ContextButton';
import { fetchNui } from '../../../utils/fetchNui';
import ReactMarkdown from 'react-markdown';
import HeaderButton from './components/HeaderButton';
import ScaleFade from '../../../transitions/ScaleFade';
import MarkdownComponents from '../../../config/MarkdownComponents';
import KeyHints from '../../../components/KeyHints';
import { displayFontFamily, panel } from '../../../theme';
import { useLocales } from '../../../providers/LocaleProvider';

const openMenu = (id: string | undefined) => {
  fetchNui<ContextMenuProps>('openContext', { id: id, back: true });
};

const useStyles = createStyles((theme) => ({
  container: {
    position: 'absolute',
    top: '15%',
    right: '25%',
    width: 400,
  },
  header: {
    alignItems: 'center',
    minHeight: 60,
    backgroundColor: panel.header,
  },
  titleContainer: {
    flex: 1,
    minWidth: 0,
    padding: '12px 20px',
  },
  titleText: {
    fontFamily: displayFontFamily,
    fontStyle: 'italic',
    fontWeight: 700,
    fontSize: 32,
    lineHeight: 1.05,
    textTransform: 'uppercase',
    color: theme.white,
    '& p, & h1, & h2, & h3': { margin: 0, font: 'inherit' },
  },
  buttonsContainer: {
    maxHeight: 460,
    overflowY: 'scroll',
    backgroundColor: panel.body,
  },
  hints: {
    display: 'flex',
    justifyContent: 'flex-end',
    marginTop: 10,
  },
}));

const ContextMenu: React.FC = () => {
  const { classes } = useStyles();
  const { locale } = useLocales();
  const [visible, setVisible] = useState(false);
  const [contextMenu, setContextMenu] = useState<ContextMenuProps>({
    title: '',
    options: { '': { description: '', metadata: [] } },
  });

  const closeContext = () => {
    if (contextMenu.canClose === false) return;
    setVisible(false);
    fetchNui('closeContext');
  };

  // Hides the context menu on ESC
  useEffect(() => {
    if (!visible) return;

    const keyHandler = (e: KeyboardEvent) => {
      if (['Escape'].includes(e.code)) closeContext();
    };

    window.addEventListener('keydown', keyHandler);

    return () => window.removeEventListener('keydown', keyHandler);
  }, [visible]);

  useNuiEvent('hideContext', () => setVisible(false));

  useNuiEvent<ContextMenuProps>('showContext', async (data) => {
    if (visible) {
      setVisible(false);
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    setContextMenu(data);
    setVisible(true);
  });

  return (
    <Box className={classes.container}>
      <ScaleFade visible={visible}>
        <Flex className={classes.header}>
          {contextMenu.menu && (
            <HeaderButton icon="chevron-left" iconSize={16} handleClick={() => openMenu(contextMenu.menu)} />
          )}
          <Box className={classes.titleContainer}>
            <Text className={classes.titleText}>
              <ReactMarkdown components={MarkdownComponents}>{contextMenu.title}</ReactMarkdown>
            </Text>
          </Box>
          <HeaderButton icon="xmark" canClose={contextMenu.canClose} iconSize={18} handleClick={closeContext} />
        </Flex>
        <Box className={classes.buttonsContainer}>
          <Stack spacing={0}>
            {Object.entries(contextMenu.options).map((option, index) => (
              <ContextButton option={option} key={`context-item-${index}`} />
            ))}
          </Stack>
        </Box>
        <Box className={classes.hints}>
          {contextMenu.canClose !== false && <KeyHints hints={[{ key: 'ESC', label: locale.ui.close }]} />}
        </Box>
      </ScaleFade>
    </Box>
  );
};

export default ContextMenu;
