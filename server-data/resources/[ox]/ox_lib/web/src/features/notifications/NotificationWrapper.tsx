import { useNuiEvent } from '../../hooks/useNuiEvent';
import { toast, Toaster } from 'react-hot-toast';
import ReactMarkdown from 'react-markdown';
import { Box, createStyles, keyframes, Text } from '@mantine/core';
import React from 'react';
import tinycolor from 'tinycolor2';
import type { IconProp } from '@fortawesome/fontawesome-svg-core';
import type { NotificationProps } from '../../typings';
import MarkdownComponents from '../../config/MarkdownComponents';
import LibIcon from '../../components/LibIcon';
import { displayFontFamily, fontFamily, panel } from '../../theme';

const useStyles = createStyles((theme) => ({
  container: {
    position: 'relative',
    display: 'flex',
    width: 380,
    height: 'fit-content',
    backgroundColor: panel.header,
    color: theme.white,
    fontFamily: fontFamily,
    boxShadow: theme.shadows.sm,
    overflow: 'hidden',
  },
  iconCell: {
    display: 'flex',
    flexShrink: 0,
    justifyContent: 'center',
    width: 60,
    padding: '16px 0',
    borderRight: '1px solid rgba(255, 255, 255, 0.14)',
    fontSize: 24,
  },
  content: {
    flex: 1,
    minWidth: 0,
    padding: '14px 16px',
    alignSelf: 'center',
  },
  title: {
    fontFamily: displayFontFamily,
    fontStyle: 'italic',
    fontWeight: 700,
    fontSize: 22,
    textTransform: 'uppercase',
    lineHeight: 1.1,
  },
  description: {
    fontSize: 18,
    fontWeight: 500,
    color: theme.colors.dark[2],
    lineHeight: 1.25,
    '& p': { margin: 0 },
    '& strong': { color: theme.colors.dark[1] },
  },
  descriptionOnly: {
    fontSize: 19,
    fontWeight: 500,
    color: theme.white,
    lineHeight: 1.25,
    '& p': { margin: 0 },
  },
  durationBar: {
    position: 'absolute',
    left: 0,
    bottom: 0,
    height: 3,
    opacity: 0.85,
  },
}));

const createAnimation = (from: string, to: string, visible: boolean) => keyframes({
  from: {
    opacity: visible ? 0 : 1,
    transform: `translate${from}`,
  },
  to: {
    opacity: visible ? 1 : 0,
    transform: `translate${to}`,
  },
});

const getAnimation = (visible: boolean, position: string) => {
  const animationOptions = visible ? '0.2s ease-out forwards' : '0.4s ease-in forwards'
  let animation: { from: string; to: string };

  if (visible) {
    animation = position.includes('bottom') ? { from: 'Y(30px)', to: 'Y(0px)' } : { from: 'Y(-30px)', to:'Y(0px)' };
  } else {
    if (position.includes('right')) {
      animation = { from: 'X(0px)', to: 'X(100%)' }
    } else if (position.includes('left')) {
      animation = { from: 'X(0px)', to: 'X(-100%)' };
    } else if (position === 'top-center') {
      animation = { from: 'Y(0px)', to: 'Y(-100%)' };
    } else if (position === 'bottom-center') {
      animation = { from: 'Y(0px)', to: 'Y(100%)' };
    } else {
      animation = { from: 'X(0px)', to: 'X(100%)' };
    }
  }

  return `${createAnimation(animation.from, animation.to, visible)} ${animationOptions}`
};

const durationLine = keyframes({
  from: { width: '100%' },
  to: { width: '0%' },
});

const defaultIcons: Record<string, { icon: IconProp; color: string }> = {
  error: { icon: 'triangle-exclamation', color: '#ff4d5e' },
  success: { icon: 'check', color: '#3ddc84' },
  warning: { icon: 'triangle-exclamation', color: '#ffc233' },
  inform: { icon: 'exclamation', color: '#3de0f5' },
};

const Notifications: React.FC = () => {
  const { classes } = useStyles();

  useNuiEvent<NotificationProps>('notify', (data) => {
    if (!data.title && !data.description) return;

    const toastId = data.id?.toString();
    const duration = data.duration || 3000;
    // Restarts the duration line when a notification with the same id is updated
    const barKey = Date.now();
    const defaults = defaultIcons[data.type as string] || defaultIcons.inform;

    let position = data.position || 'top-right';

    data.showDuration = data.showDuration !== undefined ? data.showDuration : true;

    // Backwards compat with old notifications
    switch (position) {
      case 'top':
        position = 'top-center';
        break;
      case 'bottom':
        position = 'bottom-center';
        break;
    }

    const icon = data.icon || defaults.icon;
    const iconColor = data.iconColor ? tinycolor(data.iconColor).toRgbString() : defaults.color;

    toast.custom(
      (t) => (
        <Box
          sx={{
            animation: getAnimation(t.visible, position),
            ...data.style,
          }}
          className={classes.container}
        >
          <Box
            className={classes.iconCell}
            style={{ alignItems: !data.alignIcon || data.alignIcon === 'center' ? 'center' : 'flex-start' }}
          >
            <LibIcon icon={icon} fixedWidth color={iconColor} animation={data.iconAnimation} />
          </Box>
          <Box className={classes.content}>
            {data.title && <Text className={classes.title}>{data.title}</Text>}
            {data.description && (
              <ReactMarkdown
                components={MarkdownComponents}
                className={`${!data.title ? classes.descriptionOnly : classes.description} description`}
              >
                {data.description}
              </ReactMarkdown>
            )}
          </Box>
          {data.showDuration && (
            <Box
              key={barKey}
              className={classes.durationBar}
              sx={{
                backgroundColor: iconColor,
                animation: `${durationLine} linear forwards`,
                animationDuration: `${duration}ms`,
              }}
            />
          )}
        </Box>
      ),
      {
        id: toastId,
        duration: duration,
        position: position,
      }
    );
  });

  return <Toaster />;
};

export default Notifications;
