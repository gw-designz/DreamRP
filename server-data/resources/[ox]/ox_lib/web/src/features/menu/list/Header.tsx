import { Box, createStyles, Text } from '@mantine/core';
import React from 'react';
import { displayFontFamily, panel } from '../../../theme';

const useStyles = createStyles((theme) => ({
  container: {
    backgroundColor: panel.header,
    width: 400,
    padding: '14px 20px 12px',
  },
  heading: {
    fontFamily: displayFontFamily,
    fontStyle: 'italic',
    fontSize: 34,
    fontWeight: 700,
    lineHeight: 1.05,
    textTransform: 'uppercase',
    color: theme.white,
  },
  subtitle: {
    marginTop: 2,
    fontSize: 17,
    fontWeight: 500,
    color: theme.colors.dark[2],
  },
}));

const Header: React.FC<{ title: string; subtitle?: string }> = ({ title, subtitle }) => {
  const { classes } = useStyles();

  return (
    <Box className={classes.container}>
      <Text className={classes.heading}>{title}</Text>
      {subtitle && <Text className={classes.subtitle}>{subtitle}</Text>}
    </Box>
  );
};

export default React.memo(Header);
