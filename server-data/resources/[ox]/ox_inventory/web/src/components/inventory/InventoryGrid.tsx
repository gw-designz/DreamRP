import React, { useEffect, useMemo, useState } from 'react';
import { Inventory, Slot } from '../../typings';
import InventorySlot from './InventorySlot';
import { formatWeight, getTotalWeight } from '../../helpers';
import { useAppSelector } from '../../store';
import { useIntersection } from '../../hooks/useIntersection';
import { Locale } from '../../store/locale';
import BagIcon from '../utils/icons/BagIcon';

const PAGE_SIZE = 30;
const POCKET_SLOTS = 15;

// The last slots of the player inventory are drawn as the Body and Accessories sections.
const BODY_ICONS = ['radio', 'tablet', 'idcard', 'bag', 'key', 'parachute', 'key', 'cards'];
const ACCESSORY_ICONS = ['mask', 'hat', 'glasses', 'glove'];
const EQUIPMENT_SLOTS = BODY_ICONS.length + ACCESSORY_ICONS.length;
const MIN_SLOTS_FOR_EQUIPMENT = POCKET_SLOTS + EQUIPMENT_SLOTS + 5;

const InventoryGrid: React.FC<{ inventory: Inventory }> = ({ inventory }) => {
  const weight = useMemo(
    () => (inventory.maxWeight !== undefined ? Math.floor(getTotalWeight(inventory.items) * 1000) / 1000 : 0),
    [inventory.maxWeight, inventory.items]
  );
  const [page, setPage] = useState(0);
  const { ref, entry } = useIntersection({ threshold: 0.5 });
  const isBusy = useAppSelector((state) => state.inventory.isBusy);

  useEffect(() => {
    if (entry && entry.isIntersecting) {
      setPage((prev) => ++prev);
    }
  }, [entry]);

  const visibleCount = (page + 1) * PAGE_SIZE;
  const isPlayer = inventory.type === 'player';
  const hasEquipment = isPlayer && inventory.slots >= MIN_SLOTS_FOR_EQUIPMENT;
  const equipmentStart = inventory.items.length - EQUIPMENT_SLOTS;

  const pockets = isPlayer ? inventory.items.slice(0, POCKET_SLOTS) : [];
  const bodySlots = hasEquipment ? inventory.items.slice(equipmentStart, equipmentStart + BODY_ICONS.length) : [];
  const accessorySlots = hasEquipment ? inventory.items.slice(equipmentStart + BODY_ICONS.length) : [];
  const mainSource = isPlayer
    ? inventory.items.slice(POCKET_SLOTS, hasEquipment ? equipmentStart : undefined)
    : inventory.items;
  const main = mainSource.slice(0, isPlayer ? visibleCount - POCKET_SLOTS : visibleCount);
  const lastMainSlot = main[main.length - 1]?.slot;

  const renderSlots = (items: Slot[], icons?: string[]) =>
    items.map((item, index) => (
      <InventorySlot
        key={`${inventory.type}-${inventory.id}-${item.slot}`}
        item={item}
        ref={item.slot === lastMainSlot ? ref : null}
        inventoryType={inventory.type}
        inventoryGroups={inventory.groups}
        inventoryId={inventory.id}
        placeholder={icons?.[index]}
      />
    ));

  const header = (label: string | undefined, showWeight: boolean, weightClass = '') => (
    <div className="inventory-grid-header-wrapper">
      <p>{label}</p>
      {showWeight && inventory.maxWeight && (
        <p className={`inventory-grid-weight ${weightClass}`}>
          <BagIcon />
          {formatWeight(weight)}/{formatWeight(inventory.maxWeight)}
        </p>
      )}
    </div>
  );

  return (
    <div
      className={`inventory-grid-wrapper${isPlayer ? ' inventory-grid-wrapper--player' : ''}`}
      style={{ pointerEvents: isBusy ? 'none' : 'auto' }}
    >
      {hasEquipment && (
        <div className="inventory-equipment">
          <div className="inventory-grid-section">
            {header(Locale.ui_body || 'Body', true)}
            <div className="inventory-grid-container">{renderSlots(bodySlots, BODY_ICONS)}</div>
          </div>
          <div className="inventory-grid-section">
            {header(Locale.ui_accessories || 'Accessories', false)}
            <div className="inventory-grid-container">{renderSlots(accessorySlots, ACCESSORY_ICONS)}</div>
          </div>
        </div>
      )}
      <div className="inventory-grid-main">
        {isPlayer && (
          <div className="inventory-grid-section">
            {header(Locale.ui_pockets || 'Pockets', true, hasEquipment ? 'inventory-grid-weight--quick-only' : '')}
            <div className="inventory-grid-container">{renderSlots(pockets)}</div>
          </div>
        )}
        <div className="inventory-grid-section inventory-grid-section--fill">
          {header(isPlayer ? Locale.ui_backpack || 'Backpack' : inventory.label, !isPlayer)}
          <div className="inventory-grid-container inventory-grid-container--scroll">{renderSlots(main)}</div>
        </div>
      </div>
    </div>
  );
};

export default InventoryGrid;
