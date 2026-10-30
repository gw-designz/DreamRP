import React from 'react';
import { Box, createStyles } from '@mantine/core';
import { displayFontFamily, panel } from '../theme';
import LibIcon from './LibIcon';

export type KeyHint = { key: 'enter' | 'mouse' | string; label: string };

const useStyles = createStyles((theme) => ({
  bar: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: 10,
    height: 44,
    padding: '0 14px',
    backgroundColor: panel.hint,
    color: theme.white,
    fontFamily: displayFontFamily,
    fontStyle: 'italic',
    fontWeight: 700,
    fontSize: 20,
    textTransform: 'uppercase',
    pointerEvents: 'none',
    whiteSpace: 'nowrap',
  },
  hint: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: 8,
  },
  separator: {
    color: theme.colors.dark[3],
    fontStyle: 'normal',
    fontWeight: 400,
  },
  keycap: {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    minWidth: 30,
    height: 30,
    padding: '0 6px',
    backgroundColor: theme.white,
    color: theme.colors.dark[9],
    fontSize: 15,
    lineHeight: 1,
    textShadow: 'none',
    filter: 'none',
  },
}));

const Keycap: React.FC<{ value: string }> = ({ value }) => {
  const { classes } = useStyles();

  return (
    <Box className={classes.keycap}>
      {value === 'enter' ? (
        <LibIcon icon="turn-down" rotation={90} fixedWidth />
      ) : value === 'mouse' ? (
        <LibIcon icon="computer-mouse" fixedWidth />
      ) : (
        value
      )}
    </Box>
  );
};

/** Bar of `[key] LABEL / [key] LABEL` hints shown under menus and dialogs. */
const KeyHints: React.FC<{ hints: KeyHint[]; className?: string }> = ({ hints, className }) => {
  const { classes, cx } = useStyles();

  return (
    <Box className={cx(classes.bar, className)}>
      {hints.map((hint, index) => (
        <React.Fragment key={`${hint.key}-${hint.label}`}>
          {index > 0 && <span className={classes.separator}>/</span>}
          <span className={classes.hint}>
            <Keycap value={hint.key} />
            {hint.label}
          </span>
        </React.Fragment>
      ))}
    </Box>
  );
};

export { Keycap };
export default KeyHints;
