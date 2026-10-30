import { NotificationProps } from '../../../typings';
import { debugData } from '../../../utils/debugData';

export const debugCustomNotification = () => {
  debugData<NotificationProps>([
    {
      action: 'notify',
      data: { description: 'Grabbed 7 items off the shelf', type: 'inform', duration: 8000 },
    },
    {
      action: 'notify',
      data: {
        description: "You don't have enough room in your inventory to pick this up",
        type: 'error',
        duration: 8000,
      },
    },
    {
      action: 'notify',
      data: {
        title: 'Vehicle stored',
        description: 'Your **Karin Kuruma** is in the garage',
        type: 'success',
        duration: 8000,
      },
    },
    {
      action: 'notify',
      data: { title: 'Low fuel', description: 'Find a gas station soon', type: 'warning', duration: 8000 },
    },
  ]);
};
