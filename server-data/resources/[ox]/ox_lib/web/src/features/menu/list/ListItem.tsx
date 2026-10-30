import { Box, createStyles, Group, Progress, Stack, Text } from '@mantine/core';
import { displayFontFamily, panel } from '../../../theme';
import React, { forwardRef } from 'react';
import CustomCheckbox from './CustomCheckbox';
import type { MenuItem } from '../../../typings';
import { isIconUrl } from '../../../utils/isIconUrl';
import { IconProp } from '@fortawesome/fontawesome-svg-core';
import LibIcon from '../../../components/LibIcon';

interface Props {
  item: MenuItem;
  index: number;
  scrollIndex: number;
  checked: boolean;
}

const useStyles = createStyles((theme, params: { iconColor?: string }) => ({
  buttonContainer: {
    backgroundColor: panel.row,
    color: theme.white,
    minHeight: 48,
    display: 'flex',
    alignItems: 'center',
    scrollMargin: 0,
    '&:focus': {
      backgroundColor: panel.rowSelected,
      color: theme.colors.dark[9],
      outline: 'none',
    },
  },
  iconImage: {
    maxWidth: 28,
  },
  buttonWrapper: {
    padding: '6px 20px',
    width: '100%',
  },
  iconContainer: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    width: 28,
    height: 28,
  },
  icon: {
    fontSize: 20,
    color: params.iconColor || 'inherit',
  },
  label: {
    color: 'inherit',
    fontFamily: displayFontFamily,
    fontStyle: 'italic',
    fontWeight: 700,
    fontSize: 24,
    lineHeight: 1.1,
    textTransform: 'uppercase',
  },
  description: {
    color: 'inherit',
    opacity: 0.6,
    fontSize: 16,
    fontWeight: 500,
    lineHeight: 1.2,
  },
  chevronIcon: {
    fontSize: 14,
    opacity: 0.7,
  },
  scrollIndexValue: {
    fontFamily: displayFontFamily,
    fontWeight: 700,
    fontSize: 18,
    opacity: 0.7,
  },
  scrollValue: {
    fontSize: 18,
    fontWeight: 600,
    opacity: 0.85,
  },
  progressStack: {
    width: '100%',
  },
}));

const ListItem = forwardRef<Array<HTMLDivElement | null>, Props>(({ item, index, scrollIndex, checked }, ref) => {
  const { classes } = useStyles({ iconColor: item.iconColor });
  const value = Array.isArray(item.values) ? item.values[scrollIndex] : undefined;
  const description = typeof value === 'object' ? value.description : item.description;

  return (
    <Box
      tabIndex={index}
      className={classes.buttonContainer}
      key={`item-${index}`}
      ref={(element: HTMLDivElement) => {
        if (ref)
          // @ts-ignore i cba
          return (ref.current = [...ref.current, element]);
      }}
    >
      <Group spacing={14} noWrap className={classes.buttonWrapper}>
        {item.icon && (
          <Box className={classes.iconContainer}>
            {typeof item.icon === 'string' && isIconUrl(item.icon) ? (
              <img src={item.icon} alt="Missing image" className={classes.iconImage} />
            ) : (
              <LibIcon
                icon={item.icon as IconProp}
                className={classes.icon}
                fixedWidth
                animation={item.iconAnimation}
              />
            )}
          </Box>
        )}
        {Array.isArray(item.values) ? (
          <Group position="apart" w="100%" noWrap>
            <Stack spacing={0} justify="space-between">
              <Text className={classes.label}>{item.label}</Text>
              <Text className={classes.scrollValue}>
                {typeof item.values[scrollIndex] === 'object'
                  ? // @ts-ignore for some reason even checking the type TS still thinks it's a string
                    item.values[scrollIndex].label
                  : item.values[scrollIndex]}
              </Text>
              {description && <Text className={classes.description}>{description}</Text>}
            </Stack>
            <Group spacing={4} position="center" noWrap>
              <LibIcon icon="chevron-left" className={classes.chevronIcon} />
              <Text className={classes.scrollIndexValue}>
                {scrollIndex + 1}/{item.values.length}
              </Text>
              <LibIcon icon="chevron-right" className={classes.chevronIcon} />
            </Group>
          </Group>
        ) : item.checked !== undefined ? (
          <Group position="apart" w="100%" noWrap>
            <Stack spacing={0}>
              <Text className={classes.label}>{item.label}</Text>
              {description && <Text className={classes.description}>{description}</Text>}
            </Stack>
            <CustomCheckbox checked={checked}></CustomCheckbox>
          </Group>
        ) : item.progress !== undefined ? (
          <Stack className={classes.progressStack} spacing={4}>
            <Text className={classes.label}>{item.label}</Text>
            {description && <Text className={classes.description}>{description}</Text>}
            <Progress value={item.progress} color={item.colorScheme || 'cyan'} size="sm" />
          </Stack>
        ) : (
          <Stack spacing={0}>
            <Text className={classes.label}>{item.label}</Text>
            {description && <Text className={classes.description}>{description}</Text>}
          </Stack>
        )}
      </Group>
    </Box>
  );
});

export default React.memo(ListItem);
