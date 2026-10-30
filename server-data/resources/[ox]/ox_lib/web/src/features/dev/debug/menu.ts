import { debugData } from '../../../utils/debugData';
import { MenuSettings } from '../../../typings';

export const debugMenu = () => {
  debugData<MenuSettings>([
    {
      action: 'setMenu',
      data: {
        position: 'top-left',
        title: 'Drop bun',
        subtitle: 'Select recipe',
        items: [
          { label: 'X1', icon: 'burger' },
          { label: 'X2', icon: 'burger' },
          { label: 'X3', icon: 'burger' },
          { label: 'Auto-lock', icon: 'lock', checked: true },
          {
            label: 'Sauce',
            values: ['Ketchup', 'Mustard', { label: 'Secret sauce', description: 'Do not ask what is in it' }],
            icon: 'bottle-droplet',
          },
          { label: 'Oil level', progress: 30, icon: 'oil-can', description: 'Remaining oil: 30%' },
          { label: 'Special order', icon: 'clipboard-list', description: 'Opens another menu' },
        ],
      },
    },
  ]);
};
