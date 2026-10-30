import { TextUiProps } from '../../../typings';
import { debugData } from '../../../utils/debugData';

export const debugTextUI = () => {
  debugData<TextUiProps>([
    {
      action: 'textUi',
      data: {
        text: 'Grab cereals - 35$\nInspect shelf\nReturn item',
        scroll: true,
        position: 'right-center',
      },
    },
  ]);
};
