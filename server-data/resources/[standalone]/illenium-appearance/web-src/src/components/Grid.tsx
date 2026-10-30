import React, { useState } from 'react';
import Nui from '../Nui';
import { Filter, Search, X } from 'lucide-react';
import { IconRemoveClothing } from './NpIcons';
import { IconTile, ItemCard, PageHeader, titleCase } from './ui';
import { getCategoryLucideIcon } from './CategoryIcons';
import { ClothingImages, ClothingPrices, getClothingImageCandidates, getItemPrice, getPedImageCandidates, setCachedAssetImage, getModelThumbDataUri } from '../utils';
import { flattenTattoos } from '../cart';
import ItemImage from './ItemImage';

function PedCardImage({ model }: { model: string }) {
  const candidates = React.useMemo(() => getPedImageCandidates(model), [model]);
  const [srcIndex, setSrcIndex] = useState(0);

  const fallbackUri = getModelThumbDataUri(model, "ped");
  const currentSrc = srcIndex < candidates.length ? candidates[srcIndex] : fallbackUri;

  return (
    <img
      src={currentSrc}
      alt={model}
      onError={() => {
        setSrcIndex(prev => prev + 1);
      }}
      onLoad={() => {
        if (currentSrc && !currentSrc.startsWith("data:")) {
          setCachedAssetImage(model, "ped", currentSrc);
        }
      }}
      className="w-full h-full object-contain p-1"
    />
  );
}

const APPAREL_CATEGORIES = [
  { id: 'OUTFITS', label: 'OUTFITS' },
  { id: 'CLOTHING', label: 'CLOTHING' },
  { id: 'UPPER BODY ACCESSORIES', label: 'UPPER BODY ACCESSORIES' },
  { id: 'HAND & WRIST ACCESSORIES', label: 'HAND & WRIST ACCESSORIES' },
  { id: 'HEAD ACCESSORIES', label: 'HEAD ACCESSORIES' },
];

const APPAREL_SUBCATEGORIES: Record<string, { label: string; cam: string }[]> = {
  'CLOTHING': [
    { label: 'TOPS', cam: 'body' },
    { label: 'UNDERSHIRTS', cam: 'body' },
    { label: 'BOTTOMS', cam: 'legs' },
    { label: 'SHOES', cam: 'shoes' },
  ],
  'UPPER BODY ACCESSORIES': [
    { label: 'BODY ARMOR', cam: 'body' },
    { label: 'BAGS & PARACHUTES', cam: 'body' },
    { label: 'DECALS', cam: 'body' },
  ],
  'HAND & WRIST ACCESSORIES': [
    { label: 'GLOVES', cam: 'body' },
    { label: 'WATCHES', cam: 'body' },
    { label: 'BRACELETS', cam: 'body' },
  ],
  'HEAD ACCESSORIES': [
    { label: 'MASKS', cam: 'head' },
    { label: 'HATS', cam: 'head' },
    { label: 'GLASSES', cam: 'head' },
    { label: 'EARS', cam: 'head' },
  ],
  'OUTFITS': [
    { label: 'SAVED OUTFITS', cam: 'body' },
  ]
};

// Same labels the sidebar and App.tsx use, so the zone you click is the zone you get.
const TATTOO_ZONES = [
  { label: 'HEAD' },
  { label: 'TORSO' },
  { label: 'LEFT ARM' },
  { label: 'RIGHT ARM' },
  { label: 'LEFT LEG' },
  { label: 'RIGHT LEG' },
];

const TAB_ICON_LISTS: Record<string, { label: string }[]> = {
  HAIR: [
    { label: 'STYLES' },
    { label: 'FACIAL HAIR' },
    { label: 'EYEBROWS' },
    { label: 'CHEST HAIR' },
  ],
  OVERLAYS: [
    { label: 'BLEMISHES' },
    { label: 'AGEING' },
    { label: 'COMPLEXION' },
    { label: 'SUN DAMAGE' },
    { label: 'MOLES & FRECKLES' },
    { label: 'BODY BLEMISHES' },
    { label: 'MAKEUP' },
    { label: 'BLUSH' },
    { label: 'LIPSTICK' },
    { label: 'FACIAL HAIR' },
    { label: 'EYEBROWS' },
    { label: 'CHEST HAIR' },
  ],
  'FACE & BODY': [
    { label: 'HEAD BLEND' },
    { label: 'EYE COLOR' },
    { label: 'FACE FEATURES' },
  ],
  'FACE ADJUSTMENTS': [
    { label: 'NOSE' },
    { label: 'BROW' },
    { label: 'EYES' },
    { label: 'CHEEKS' },
    { label: 'LIPS & JAW' },
    { label: 'CHIN & NECK' },
  ],
};

export default function Grid({ 
  navPath,
  setNavPath,
  activeCategory, 
  itemType, 
  itemId, 
  itemsToRender, 
  activeItem,
  gender,
  appearanceData,
  onItemSelect,
  onModelApplied,
  isFree,
  prices,
  images
}: { 
  navPath: string[];
  setNavPath: (path: string[]) => void;
  activeCategory: string;
  itemType: string;
  itemId: number;
  itemsToRender: any[];
  activeItem: any;
  gender?: 'male' | 'female';
  appearanceData?: any;
  onItemSelect?: (item: any) => void;
  onModelApplied?: (res: { appearanceData?: any; appearanceSettings?: any }) => void;
  isFree?: boolean;
  prices?: ClothingPrices;
  images?: ClothingImages;
}) {
  const [searchQuery, setSearchQuery] = useState('');

  if (!activeCategory || itemsToRender.length === 0) return null;

  const resolvePrice = (item: any) => {
    switch (itemType) {
      case 'component':
        return getItemPrice(prices, !!isFree, 'component', itemId, item.drawable);
      case 'prop':
        return getItemPrice(prices, !!isFree, 'prop', itemId, item.drawable);
      case 'hair':
        return getItemPrice(prices, !!isFree, 'hair');
      case 'overlay':
        return getItemPrice(prices, !!isFree, 'overlay');
      case 'eye_color':
        return getItemPrice(prices, !!isFree, 'eyeColor');
      case 'tattoo':
        return getItemPrice(prices, !!isFree, 'tattoo', 0, 0, item.cost);
      default:
        return 0;
    }
  };

  const ownedTattoos = flattenTattoos(appearanceData?.tattoos);

  // Picking an item only changes how the player looks. Nothing is charged here:
  // the total at the bottom is worked out from what actually changed (see cart.ts).
  const handleUpdateItem = (drawable: number, texture: number) => {
    if (itemType === 'ped_model') {
      const targetItem = itemsToRender[drawable] || itemsToRender.find(it => it.drawable === drawable);
      const modelName = targetItem?.model || targetItem?.name;
      if (modelName) {
        if (onItemSelect) onItemSelect({ model: modelName, name: modelName });
        Nui.post('appearance_change_model', modelName).then((res: any) => {
          if (res && onModelApplied) {
            onModelApplied(res);
          } else if (res?.appearanceData && onItemSelect) {
            onItemSelect(res.appearanceData);
          }
        });
      }
      return;
    }

    if (itemType === 'tattoo') {
      const tattooItem = itemsToRender[drawable] || itemsToRender.find(it => it.drawable === drawable);
      if (tattooItem) {
        const { drawable: _d, texture: _t, ...tattoo } = tattooItem;
        const owned = ownedTattoos.some((t: any) => t.name === tattoo.name);
        if (owned) {
          Nui.post('appearance_delete_tattoo', { name: tattoo.name, zone: tattoo.zone });
        } else {
          Nui.post('appearance_apply_tattoo', { tattoo, updatedTattoos: [tattoo] });
        }
        if (onItemSelect) onItemSelect({ ...tattoo, _remove: owned });
      }
      return;
    }

    if (itemType === 'component') {
      Nui.post('appearance_change_component', { component_id: itemId, drawable, texture });
      if (onItemSelect) onItemSelect({ component_id: itemId, drawable, texture });
    } else if (itemType === 'prop') {
      Nui.post('appearance_change_prop', { prop_id: itemId, drawable, texture });
      if (onItemSelect) onItemSelect({ prop_id: itemId, drawable, texture });
    } else if (itemType === 'eye_color') {
      Nui.post('appearance_change_eye_color', drawable);
      if (onItemSelect) onItemSelect({ drawable, texture: 0 });
    } else if (itemType === 'hair') {
      const color = appearanceData?.hair?.color || 0;
      const highlight = appearanceData?.hair?.highlight || 0;
      Nui.post('appearance_change_hair', { style: drawable, color, highlight });
      if (onItemSelect) onItemSelect({ drawable, texture: 0 });
    } else if (itemType === 'overlay') {
      const overlayItem = itemsToRender[drawable] || itemsToRender.find(it => it.drawable === drawable);
      const overlayKey = overlayItem?.overlayKey;
      if (overlayKey) {
        const current = appearanceData?.headOverlays?.[overlayKey] || {};
        Nui.post('appearance_change_head_overlay', {
          key: overlayKey,
          style: drawable,
          opacity: current.opacity ?? 1,
          color: current.color || 0,
          secondColor: current.secondColor || 0,
        });
        if (onItemSelect) onItemSelect({ drawable, texture: 0, overlayKey, style: drawable });
      }
    }
  };

  const handleRemoveItem = () => {
    if (itemType === 'component') {
      Nui.post('appearance_change_component', { component_id: itemId, drawable: 0, texture: 0 });
      if (onItemSelect) onItemSelect({ component_id: itemId, drawable: 0, texture: 0 });
    } else if (itemType === 'prop') {
      Nui.post('appearance_change_prop', { prop_id: itemId, drawable: -1, texture: 0 });
      if (onItemSelect) onItemSelect({ prop_id: itemId, drawable: -1, texture: 0 });
    } else if (itemType === 'tattoo') {
      // clear every tattoo in the zone that is currently open
      const zone = itemsToRender[0]?.zone;
      ownedTattoos
        .filter((t: any) => t.zone === zone)
        .forEach((t: any) => {
          Nui.post('appearance_delete_tattoo', { name: t.name, zone: t.zone });
          if (onItemSelect) onItemSelect({ ...t, _remove: true });
        });
    } else if (itemType === 'overlay') {
      const overlayKey = activeItem?.overlayKey || itemsToRender[0]?.overlayKey;
      if (overlayKey) {
        const current = appearanceData?.headOverlays?.[overlayKey] || {};
        Nui.post('appearance_change_head_overlay', {
          key: overlayKey,
          style: 255,
          opacity: 0,
          color: current.color || 0,
          secondColor: current.secondColor || 0,
        });
        if (onItemSelect) onItemSelect({ drawable: 255, texture: 0, overlayKey, style: 255 });
      }
    } else if (itemType === 'hair') {
      const color = appearanceData?.hair?.color || 0;
      const highlight = appearanceData?.hair?.highlight || 0;
      Nui.post('appearance_change_hair', { style: 0, color, highlight });
      if (onItemSelect) onItemSelect({ drawable: 0, texture: 0 });
    }
  };

  const mainTab = navPath[0];
  const currentFolder = navPath.length >= 2 ? navPath[1] : '';
  const currentSubList = APPAREL_SUBCATEGORIES[currentFolder] || [];

  const filteredItems = itemsToRender.filter(item => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase().trim();
    if (itemType === 'ped_model') {
      const modelName = (item.model || item.name || '').toLowerCase();
      const cleanModelName = modelName.replace(/_/g, ' ');
      const cleanQ = q.replace(/_/g, ' ');
      return modelName.includes(q) || cleanModelName.includes(cleanQ);
    }
    if (itemType === 'tattoo') {
      const label = (item.label || item.name || '').toLowerCase();
      const coll = (item.collection || '').toLowerCase();
      return label.includes(q) || coll.includes(q);
    }
    const name = `${activeCategory} ${item.drawable}`.toLowerCase();
    return name.includes(q) || String(item.drawable).includes(q);
  });

  const iconClass = 'w-6 h-6';

  const renderIconColumn = (
    items: { label: string }[],
    isActive: (label: string) => boolean,
    onPick: (label: string) => void,
    scroll = false,
  ) => (
    <div className={`flex flex-col gap-[4px] ${scroll ? 'max-h-[calc(100vh-250px)] overflow-y-auto styled-scrollbar' : ''}`}>
      {items.map((sub) => (
        <IconTile key={sub.label} title={sub.label} active={isActive(sub.label)} onClick={() => onPick(sub.label)}>
          {getCategoryLucideIcon(sub.label, iconClass)}
        </IconTile>
      ))}
    </div>
  );

  const getItemName = (item: any) => {
    if (itemType === 'ped_model') return item.model || item.name || '';
    if (itemType === 'tattoo') return item.label || item.name || '';
    if (itemType === 'overlay') return item.drawable === 0 ? 'None' : `Style ${item.drawable}`;
    if (itemType === 'hair') return `Style ${item.drawable}`;
    if (itemType === 'eye_color') return `Color ${item.drawable}`;
    return `${titleCase(activeCategory)} ${item.drawable}`;
  };

  return (
    <div className="flex flex-col pointer-events-auto select-none relative z-10">
      <PageHeader navPath={navPath} setNavPath={setNavPath} />

      <div className="flex gap-[4px]">
        {mainTab === 'APPAREL' && (
          <>
            {renderIconColumn(
              APPAREL_CATEGORIES,
              (label) => currentFolder === label,
              (label) => {
                const firstSub = APPAREL_SUBCATEGORIES[label]?.[0]?.label || label;
                setNavPath(['APPAREL', label, firstSub]);
              },
            )}
            {currentSubList.length > 0 &&
              renderIconColumn(
                currentSubList,
                (label) => activeCategory === label,
                (label) => setNavPath(['APPAREL', currentFolder, label]),
              )}
          </>
        )}

        {TAB_ICON_LISTS[mainTab] &&
          renderIconColumn(
            TAB_ICON_LISTS[mainTab],
            (label) => activeCategory === label,
            (label) => setNavPath([mainTab, label]),
            true,
          )}

        {mainTab === 'TATTOOS' &&
          renderIconColumn(
            TATTOO_ZONES,
            (label) => activeCategory === label,
            (label) => setNavPath(['TATTOOS', label]),
          )}

        <div className="w-[492px] flex flex-col ml-[6px]">
          <div className="h-[32px] flex items-stretch gap-[4px] mb-[4px]">
           <div className="np-panel flex-1 min-w-0 flex items-center">
            <Search className="w-4 h-4 ml-2.5 text-white/60 flex-shrink-0" strokeWidth={2.5} />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search..."
              className="flex-1 min-w-0 h-full bg-transparent border-none outline-none px-2 font-np font-medium text-[15px] text-white placeholder-white/40"
            />
            {searchQuery && (
              <button type="button" onClick={() => setSearchQuery('')} className="px-1.5 text-white/50 hover:text-white cursor-pointer">
                <X className="w-4 h-4" />
              </button>
            )}
           </div>
            <button type="button" title="Filter" className="np-panel w-[34px] flex items-center justify-center text-white/70 hover:text-white cursor-pointer">
              <Filter className="w-4 h-4" fill="currentColor" />
            </button>
            <button
              type="button"
              title="Remove"
              onClick={handleRemoveItem}
              className="np-panel w-[34px] flex items-center justify-center text-white/70 hover:text-white cursor-pointer"
            >
              <IconRemoveClothing className="w-5 h-5" />
            </button>
          </div>

          <div className="grid grid-cols-3 auto-rows-max content-start gap-[6px] overflow-y-auto max-h-[calc(100vh-290px)] pr-[6px] styled-scrollbar">
            {filteredItems.map((item) => {
              const isPedModel = itemType === 'ped_model';
              const isTattoo = itemType === 'tattoo';
              const isOverlay = itemType === 'overlay';
              const isActive = isPedModel
                ? (appearanceData?.model === item.model || activeItem?.model === item.model)
                : isTattoo
                ? ownedTattoos.some((t: any) => t.name === item.name)
                : (activeItem?.drawable === item.drawable);

              let candidates: string[] = [];
              if (itemType === 'component' || itemType === 'prop') {
                candidates = getClothingImageCandidates(images, itemType, itemId, item.drawable, item.texture || 0, gender);
              } else if (itemType === 'hair') {
                candidates = getClothingImageCandidates(images, 'hair', 2, item.drawable, item.texture || 0, gender);
              } else if (isOverlay) {
                candidates = getClothingImageCandidates(images, 'overlay', item.overlayKey || itemId, item.drawable, 0, gender);
              }

              const placeholder = (
                <div className="flex flex-col items-center justify-center gap-1 text-white/45">
                  {isTattoo ? (
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-8 h-8">
                      <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
                    </svg>
                  ) : (
                    getCategoryLucideIcon(activeCategory, 'w-9 h-9')
                  )}
                  {isTattoo && item.collection && (
                    <span className="font-np text-[11px] uppercase truncate max-w-[130px]">{item.collection}</span>
                  )}
                </div>
              );

              return (
                <ItemCard
                  key={`${itemType}-${itemId}-${activeCategory}-${item.drawable}`}
                  name={getItemName(item)}
                  price={isPedModel ? undefined : resolvePrice(item)}
                  isFree={isFree}
                  active={isActive}
                  onClick={() => handleUpdateItem(item.drawable, item.texture || 0)}
                >
                  {isPedModel ? (
                    <PedCardImage model={item.model || item.name} />
                  ) : isTattoo ? (
                    placeholder
                  ) : (
                    <ItemImage candidates={candidates} fallback={placeholder} />
                  )}
                </ItemCard>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
