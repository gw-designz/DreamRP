import React, { useEffect, useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryControl from './InventoryControl';
import InventoryHotbar from './InventoryHotbar';
import { useAppDispatch, useAppSelector } from '../../store';
import { selectLeftInventory, selectRightInventory } from '../../store/inventory';
import InventoryFilter from './InventoryFilter';
import HintBar from './HintBar';
import { Locale } from '../../store/locale';
import { refreshSlots, setAdditionalMetadata, setupInventory } from '../../store/inventory';
import { useExitListener } from '../../hooks/useExitListener';
import type { Inventory as InventoryProps } from '../../typings';
import RightInventory from './RightInventory';
import LeftInventory from './LeftInventory';
import Tooltip from '../utils/Tooltip';
import { closeTooltip } from '../../store/tooltip';
import InventoryContext from './InventoryContext';
import { closeContextMenu } from '../../store/contextMenu';
import { resetFilter } from '../../store/filter';
import Fade from '../utils/transitions/Fade';
import { isEnvBrowser } from '../../utils/misc';

const Inventory: React.FC = () => {
  const [inventoryVisible, setInventoryVisible] = useState(false);
  const [quickStash, setQuickStash] = useState(false);
  const dispatch = useAppDispatch();

  useNuiEvent<boolean>('setInventoryVisible', setInventoryVisible);
  useNuiEvent<boolean>('setQuickStash', setQuickStash);
  useNuiEvent<false>('closeInventory', () => {
    setInventoryVisible(false);
    dispatch(closeContextMenu());
    dispatch(closeTooltip());
    dispatch(resetFilter());
  });
  useExitListener(setInventoryVisible);

  useNuiEvent<{
    leftInventory?: InventoryProps;
    rightInventory?: InventoryProps;
  }>('setupInventory', (data) => {
    dispatch(setupInventory(data));
    !inventoryVisible && setInventoryVisible(true);
  });

  // The quick stash layout only lasts for a single opening
  useEffect(() => {
    if (!inventoryVisible) setQuickStash(false);
  }, [inventoryVisible]);

  // In the browser there is no Lua keybind, so Z toggles the quick stash for previewing
  useEffect(() => {
    if (!isEnvBrowser()) return;

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key.toLowerCase() !== 'z' || (event.target as HTMLElement).tagName === 'INPUT') return;
      setQuickStash((prev) => !prev);
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, []);

  const leftInventory = useAppSelector(selectLeftInventory);
  const rightInventory = useAppSelector(selectRightInventory);

  useNuiEvent('refreshSlots', (data) => dispatch(refreshSlots(data)));

  useNuiEvent('displayMetadata', (data: Array<{ metadata: string; value: string }>) => {
    dispatch(setAdditionalMetadata(data));
  });

  return (
    <>
      <Fade in={inventoryVisible}>
        <div className={`inventory-wrapper${quickStash ? ' inventory-wrapper--quick' : ''}`}>
          <header className="inventory-header">
            <div className="inventory-title">
              <h1>{Locale.ui_inventory || 'Inventory'}</h1>
              <span>{quickStash ? Locale.ui_quick_stash || 'Quick stash' : leftInventory.label}</span>
            </div>
            {!quickStash && (
              <>
                <InventoryFilter />
                <InventoryControl />
              </>
            )}
          </header>
          <main className="inventory-body">
            <LeftInventory />
            {!quickStash && rightInventory.id && (
              <>
                <div className="inventory-divider" />
                <RightInventory />
              </>
            )}
          </main>
          <HintBar />
          <Tooltip />
          <InventoryContext />
        </div>
      </Fade>
      <InventoryHotbar />
    </>
  );
};

export default Inventory;
