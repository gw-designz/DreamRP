import InventoryComponent from './components/inventory';
import useNuiEvent from './hooks/useNuiEvent';
import { Items } from './store/items';
import { Locale } from './store/locale';
import { setImagePath } from './store/imagepath';
import { setupInventory } from './store/inventory';
import { Inventory } from './typings';
import { useAppDispatch } from './store';
import { debugData } from './utils/debugData';
import DragPreview from './components/utils/DragPreview';
import { fetchNui } from './utils/fetchNui';
import { useDragDropManager } from 'react-dnd';
import KeyPress from './components/utils/KeyPress';
import UiSounds from './components/utils/UiSounds';

debugData([
  {
    action: 'init',
    data: {
      imagepath: 'images',
      locale: {
        ui_use: 'Use',
        ui_give: 'Give',
        ui_drop: 'Drop',
        ui_close: 'Close',
        ui_usefulcontrols: 'Useful controls',
      },
      items: {
        WEAPON_PISTOL: { name: 'WEAPON_PISTOL', label: 'Pistol', stack: false, usable: true, close: true, count: 0 },
        WEAPON_BAT: { name: 'WEAPON_BAT', label: 'Baseball Bat', stack: false, usable: true, close: true, count: 0 },
        sprunk: {
          name: 'sprunk',
          label: 'Sprunk',
          stack: true,
          usable: true,
          close: false,
          count: 0,
          description: 'An ice cold, refreshing soda.',
        },
        burger: {
          name: 'burger',
          label: 'Burger',
          stack: true,
          usable: true,
          close: false,
          count: 0,
          description: 'A classic hamburger that restores hunger.',
        },
        phone: { name: 'phone', label: 'Phone', stack: false, usable: true, close: true, count: 0 },
        radio: { name: 'radio', label: 'Radio', stack: false, usable: true, close: true, count: 0 },
        'ammo-9': { name: 'ammo-9', label: '9mm Rounds', stack: true, usable: false, close: false, count: 0 },
        medikit: { name: 'medikit', label: 'Medikit', stack: true, usable: true, close: true, count: 0 },
        money: { name: 'money', label: 'Money', stack: true, usable: false, close: false, count: 0 },
        lockpick: { name: 'lockpick', label: 'Lockpick', stack: true, usable: true, close: true, count: 0 },
      },
    },
  },
  {
    action: 'setupInventory',
    data: {
      leftInventory: {
        id: 'test',
        type: 'player',
        slots: 50,
        label: 'Bob Smith',
        weight: 6600,
        maxWeight: 115000,
        items: [
          {
            slot: 1,
            name: 'WEAPON_PISTOL',
            weight: 1130,
            count: 1,
            metadata: { durability: 80, ammo: 12, serial: '12345678' },
          },
          { slot: 2, name: 'WEAPON_BAT', weight: 1000, count: 1, metadata: { durability: 45 } },
          { slot: 3, name: 'sprunk', weight: 500, count: 3 },
          { slot: 4, name: 'burger', weight: 220, count: 10, metadata: { type: 'Burger' } },
          { slot: 5, name: 'phone', weight: 300, count: 1 },
          { slot: 39, name: 'radio', weight: 500, count: 1 },
          { slot: 7, name: 'ammo-9', weight: 8, count: 30 },
          { slot: 8, name: 'medikit', weight: 300, count: 3 },
          { slot: 9, name: 'money', weight: 0, count: 5 },
        ],
      },
      rightInventory: {
        id: 'drop',
        type: 'drop',
        slots: 50,
        label: 'Newdrop',
        weight: 0,
        maxWeight: 85000,
        items: [],
      },
    },
  },
]);

const App: React.FC = () => {
  const dispatch = useAppDispatch();
  const manager = useDragDropManager();

  useNuiEvent<{
    locale: { [key: string]: string };
    items: typeof Items;
    leftInventory: Inventory;
    imagepath: string;
  }>('init', ({ locale, items, leftInventory, imagepath }) => {
    for (const name in locale) Locale[name] = locale[name];
    for (const name in items) Items[name] = items[name];

    setImagePath(imagepath);
    dispatch(setupInventory({ leftInventory }));
  });

  fetchNui('uiLoaded', {});

  useNuiEvent('closeInventory', () => {
    manager.dispatch({ type: 'dnd-core/END_DRAG' });
  });

  return (
    <div className="app-wrapper">
      <InventoryComponent />
      <DragPreview />
      <KeyPress />
      <UiSounds />
    </div>
  );
};

addEventListener('dragstart', function (event) {
  event.preventDefault();
});

export default App;
