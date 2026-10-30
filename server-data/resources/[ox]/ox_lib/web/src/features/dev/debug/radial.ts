import { debugData } from '../../../utils/debugData';
import type { RadialMenuItem } from '../../../typings';

export const debugRadial = () => {
  debugData<{ items: RadialMenuItem[]; sub?: boolean }>([
    {
      action: 'openRadialMenu',
      data: {
        items: [
          { icon: 'hand-holding-medical', label: 'Inspect health' },
          { icon: 'hands-clapping', label: 'Emotes' },
          { icon: 'user-gear', label: 'Player interact' },
        ],
      },
    },
  ]);
};
