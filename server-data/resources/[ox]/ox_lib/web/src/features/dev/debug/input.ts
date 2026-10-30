import { debugData } from '../../../utils/debugData';
import type { InputProps } from '../../../typings';

export const debugInput = () => {
  debugData<InputProps>([
    {
      action: 'openDialog',
      data: {
        heading: 'Police locker',
        rows: [
          {
            type: 'input',
            label: 'Locker number',
            description: 'The number on the locker door',
            icon: 'hashtag',
            default: '360',
            required: true,
          },
          { type: 'input', label: 'PIN', password: true, icon: 'lock', placeholder: '****' },
          {
            type: 'select',
            label: 'Locker type',
            default: 'evidence',
            options: [
              { value: 'evidence', label: 'Evidence' },
              { value: 'personal', label: 'Personal' },
            ],
          },
          { type: 'number', label: 'Amount', default: 3, min: 1, max: 10, icon: 'receipt' },
          { type: 'checkbox', label: 'Lock after closing', checked: true },
          { type: 'slider', label: 'Volume', min: 0, max: 100, default: 40 },
          { type: 'date', label: 'Date', icon: 'calendar', format: 'DD/MM/YYYY', default: true },
          { type: 'textarea', label: 'Notes', placeholder: 'Write something...' },
        ],
      },
    },
  ]);
};
