import { useEffect } from 'react';
import { playSound } from '../../utils/sound';

const INTERACTIVE = 'button, .inventory-slot--filled';

// One delegated listener so every button, item slot and context menu entry gets hover/click feedback
const UiSounds: React.FC = () => {
  useEffect(() => {
    const onOver = (event: MouseEvent) => {
      if (document.body.classList.contains('inv-dragging')) return;

      const target = (event.target as HTMLElement | null)?.closest(INTERACTIVE);
      if (!target || target.contains(event.relatedTarget as Node | null)) return;

      playSound('hover');
    };

    const onClick = (event: MouseEvent) => {
      if ((event.target as HTMLElement | null)?.closest(INTERACTIVE)) playSound('click');
    };

    window.addEventListener('mouseover', onOver);
    window.addEventListener('click', onClick);

    return () => {
      window.removeEventListener('mouseover', onOver);
      window.removeEventListener('click', onClick);
    };
  }, []);

  return null;
};

export default UiSounds;
