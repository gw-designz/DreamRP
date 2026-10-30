import { useEffect } from 'react';
import { AnimatePresence } from 'framer-motion';
import { Target } from './Target';
import { useTargetStore } from './store';

/**
 * The client sends `{ event, data }`, where `event` is a store action name -
 * the same dispatch the original hud used for its `target:<action>` events.
 */
interface NuiMessage {
  event: string;
  data: unknown;
}

export const App = () => {
  const visible = useTargetStore((state) => state.visible);

  useEffect(() => {
    const onMessage = (event: MessageEvent<NuiMessage>) => {
      const message = event.data;

      if (!message || typeof message.event !== 'string') return;

      const action = useTargetStore.getState()[message.event as keyof ReturnType<typeof useTargetStore.getState>];

      if (typeof action === 'function') (action as (value: unknown) => void)(message.data);
    };

    window.addEventListener('message', onMessage);

    return () => window.removeEventListener('message', onMessage);
  }, []);

  return <AnimatePresence>{visible && <Target />}</AnimatePresence>;
};
