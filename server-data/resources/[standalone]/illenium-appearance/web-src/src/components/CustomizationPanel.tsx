import React, { useEffect, useMemo, useState } from 'react';
import Nui from '../Nui';
import { ClothingImages, ClothingPrices, getClothingImageCandidates, getItemPrice } from '../utils';
import ItemImage from './ItemImage';
import { getCategoryLucideIcon } from './CategoryIcons';
import { ItemCard, Section, TabBar, titleCase } from './ui';

export const GTA_HAIR_COLORS: string[] = [
  "#1c1e1d", "#36302e", "#3c2e28", "#462d22", "#562d1d", "#6e331d", "#7e371e", "#914122",
  "#974c26", "#8b4d2b", "#985832", "#9b6038", "#a66838", "#a66f3b", "#b27a3e", "#b98845",
  "#b48a4c", "#ad844e", "#9a7446", "#6c5035", "#6c5339", "#8c6c44", "#9b7849", "#ab8852",
  "#c8a562", "#d6b56d", "#d1af69", "#d7b46d", "#b58d53", "#8d643b", "#583f28", "#8e3b23",
  "#a03623", "#a82f23", "#9d1f23", "#7d1e23", "#82262d", "#9a3140", "#a63351", "#8b2649",
  "#731e40", "#842557", "#98286a", "#8c2a78", "#5e1e63", "#742278", "#6a1d74", "#3e1957",
  "#28174e", "#251c59", "#1b2064", "#1c326e", "#1d4474", "#1b516b", "#1a5b60", "#1d6d5c",
  "#227b56", "#267b40", "#5b8a36", "#7c932e", "#8c9b32", "#a5a837", "#b3aa37", "#c2a637"
];

// Colours are read from the game itself (GetPedHairRgbColor / GetPedMakeupRgbColor), because
// hair, beard, eyebrows and chest hair use a different palette than makeup, blush and
// lipstick. The list above is only a fallback for when the game data isn't available.
const rgbToHex = (rgb: any): string | null => {
  const [r, g, b] = Array.isArray(rgb) ? rgb : [rgb?.r, rgb?.g, rgb?.b];
  if ([r, g, b].some((v) => typeof v !== 'number')) return null;
  const h = (v: number) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0');
  return `#${h(r)}${h(g)}${h(b)}`;
};

const OVERLAY_CATEGORY_MAP: Record<string, string> = {
  'FACIAL HAIR': 'beard',
  'beard': 'beard',
  'EYEBROWS': 'eyebrows',
  'eyebrows': 'eyebrows',
  'MAKEUP': 'makeUp',
  'makeUp': 'makeUp',
  'BLUSH': 'blush',
  'blush': 'blush',
  'LIPSTICK': 'lipstick',
  'lipstick': 'lipstick',
  'CHEST HAIR': 'chestHair',
  'chestHair': 'chestHair',
};

export type ItemKind = 'component' | 'prop';

type RelatedTab = { label: string; type: ItemKind; id: number; singular: string };

// Extra tabs next to STYLES, like the shop's "UNDERSHIRTS / NECKWEAR" when picking a top.
const RELATED_TABS: Record<string, RelatedTab[]> = {
  TOPS: [
    { label: 'UNDERSHIRTS', type: 'component', id: 8, singular: 'UNDERSHIRT' },
    { label: 'NECKWEAR', type: 'component', id: 7, singular: 'NECKWEAR' },
  ],
  UNDERSHIRTS: [{ label: 'NECKWEAR', type: 'component', id: 7, singular: 'NECKWEAR' }],
  HATS: [
    { label: 'GLASSES', type: 'prop', id: 1, singular: 'GLASSES' },
    { label: 'EARS', type: 'prop', id: 2, singular: 'EAR' },
  ],
  WATCHES: [{ label: 'BRACELETS', type: 'prop', id: 7, singular: 'BRACELET' }],
};

/** How many textures the item the ped currently wears in that slot has (asked from the game). */
function useTextureMax(type: ItemKind, id: number | undefined, drawable: number | undefined, enabled: boolean) {
  const [textureMax, setTextureMax] = useState<number | null>(null);

  useEffect(() => {
    if (!enabled || id === undefined || drawable === undefined || drawable < 0) {
      setTextureMax(null);
      return;
    }
    let cancelled = false;
    setTextureMax(null);
    Nui.post('appearance_get_item_settings', { type, id }).then((res: any) => {
      if (!cancelled && typeof res?.texture?.max === 'number') setTextureMax(res.texture.max);
    });
    return () => {
      cancelled = true;
    };
  }, [enabled, type, id, drawable]);

  return textureMax;
}

const findWorn = (appearanceData: any, type: ItemKind, id: number) => {
  const list = type === 'component' ? appearanceData?.components : appearanceData?.props;
  const key = type === 'component' ? 'component_id' : 'prop_id';
  return (list || []).find((x: any) => x?.[key] === id);
};

export default function CustomizationPanel({
  activeCategory,
  activeItem,
  appearanceData,
  setAppearanceData,
  appearanceSettings,
  gender,
  onTextureSelect,
  onApplyItem,
  images,
  prices,
  isFree,
}: {
  activeCategory: string;
  activeItem?: any;
  appearanceData?: any;
  setAppearanceData?: React.Dispatch<React.SetStateAction<any>>;
  appearanceSettings?: any;
  gender?: 'male' | 'female';
  onTextureSelect?: (textureId: number) => void;
  onApplyItem?: (type: ItemKind, id: number, drawable: number, texture: number) => void;
  images?: ClothingImages;
  prices?: ClothingPrices;
  isFree?: boolean;
}) {
  const [colorTarget, setColorTarget] = useState<'primary' | 'secondary'>('primary');
  const [mixType, setMixType] = useState<'mixA' | 'mixB'>('mixB');
  const [activeTab, setActiveTab] = useState('STYLES');
  const [openSections, setOpenSections] = useState<Record<string, boolean>>({});

  const isHairCat = activeCategory === 'HAIR' || activeCategory === 'STYLES' || activeCategory === 'HAIRSTYLE';
  const overlayKey = OVERLAY_CATEGORY_MAP[activeCategory];
  const isColorCat = isHairCat || !!overlayKey;

  const relatedTabs = RELATED_TABS[activeCategory] || [];
  const related = relatedTabs.find((t) => t.label === activeTab);

  useEffect(() => {
    setActiveTab('STYLES');
    setOpenSections({});
  }, [activeCategory]);

  const isOpen = (key: string, fallback: boolean) => openSections[key] ?? fallback;
  const toggle = (key: string, fallback: boolean) => setOpenSections((prev) => ({ ...prev, [key]: !(prev[key] ?? fallback) }));

  const palette = useMemo(() => {
    const raw = isHairCat ? appearanceSettings?.hair?.color?.items : overlayKey ? appearanceSettings?.headOverlays?.[overlayKey]?.color?.items : undefined;
    if (Array.isArray(raw) && raw.length > 0) {
      const mapped = raw.map((c: any, i: number) => rgbToHex(c) || GTA_HAIR_COLORS[i] || '#1c1e1d');
      return mapped as string[];
    }
    return GTA_HAIR_COLORS;
  }, [appearanceSettings, isHairCat, overlayKey]);

  const wornType: ItemKind = activeItem?.component_id !== undefined ? 'component' : 'prop';
  const wornId = wornType === 'component' ? activeItem?.component_id : activeItem?.prop_id;
  const textureMax = useTextureMax(wornType, wornId, activeItem?.drawable, !isColorCat);

  const relatedWorn = related ? findWorn(appearanceData, related.type, related.id) : undefined;
  const relatedDrawable = related ? relatedWorn?.drawable ?? (related.type === 'prop' ? -1 : 0) : undefined;
  const relatedTextureMax = useTextureMax(related?.type ?? 'component', related?.id, relatedDrawable, !!related);

  const title = (
    <h1 className="np-title text-[54px] uppercase text-right mb-3 h-[56px] flex items-center justify-end">CUSTOMIZATION</h1>
  );

  if (isColorCat) {
    let primaryColor = 0;
    let secondaryColor = 0;
    let styleVal = 0;
    let opacityVal = 1.0;

    if (isHairCat) {
      styleVal = appearanceData?.hair?.style !== undefined ? appearanceData.hair.style : (activeItem?.drawable ?? 0);
      primaryColor = appearanceData?.hair?.color ?? 0;
      secondaryColor = appearanceData?.hair?.highlight ?? 0;
    } else if (overlayKey) {
      const ov = appearanceData?.headOverlays?.[overlayKey] || {};
      styleVal = ov.style ?? 0;
      opacityVal = ov.opacity ?? 1.0;
      primaryColor = ov.color ?? 0;
      secondaryColor = ov.secondColor ?? 0;
    }

    const handleSelectColor = (cIdx: number) => {
      if (isHairCat) {
        const newPrimary = colorTarget === 'primary' ? cIdx : primaryColor;
        const newSecondary = colorTarget === 'secondary' ? cIdx : secondaryColor;

        if (setAppearanceData) {
          setAppearanceData((prev: any) => ({
            ...prev,
            hair: {
              ...(prev?.hair || {}),
              style: styleVal,
              color: newPrimary,
              highlight: newSecondary
            }
          }));
        }
        Nui.post('appearance_change_hair', {
          style: styleVal,
          color: newPrimary,
          highlight: newSecondary
        });
      } else if (overlayKey) {
        const newPrimary = colorTarget === 'primary' ? cIdx : primaryColor;
        const newSecondary = colorTarget === 'secondary' ? cIdx : secondaryColor;
        const updatedOverlay = {
          style: styleVal,
          opacity: opacityVal,
          color: newPrimary,
          secondColor: newSecondary
        };

        if (setAppearanceData) {
          setAppearanceData((prev: any) => ({
            ...prev,
            headOverlays: {
              ...(prev?.headOverlays || {}),
              [overlayKey]: updatedOverlay
            }
          }));
        }
        Nui.post('appearance_change_head_overlay', {
          key: overlayKey,
          style: styleVal,
          opacity: opacityVal,
          color: newPrimary,
          secondColor: newSecondary
        });
      }
    };

    const handleOpacityChange = (newOpacity: number) => {
      const clamped = Math.min(Math.max(newOpacity, 0.0), 1.0);
      if (overlayKey) {
        const updatedOverlay = {
          style: styleVal,
          opacity: clamped,
          color: primaryColor,
          secondColor: secondaryColor
        };
        if (setAppearanceData) {
          setAppearanceData((prev: any) => ({
            ...prev,
            headOverlays: {
              ...(prev?.headOverlays || {}),
              [overlayKey]: updatedOverlay
            }
          }));
        }
        Nui.post('appearance_change_head_overlay', {
          key: overlayKey,
          style: styleVal,
          opacity: clamped,
          color: primaryColor,
          secondColor: secondaryColor
        });
      }
    };

    const currentSelectedColorIndex = colorTarget === 'primary' ? primaryColor : secondaryColor;
    const primaryHex = palette[primaryColor] || '#1c1e1d';
    const secondaryHex = palette[secondaryColor] || '#1c1e1d';

    const swatchButton = (selected: boolean, onClick: () => void, background: string, label: string) => (
      <button
        type="button"
        onClick={onClick}
        className={`relative flex flex-col cursor-pointer np-card transition-colors`}
      >
        <div className="w-full h-12" style={{ background }} />
        <span className="h-[24px] flex items-center px-2 font-np font-semibold text-[13px] text-white bg-black/40">{label}</span>
        <span className={`absolute inset-0 pointer-events-none border-2 ${selected ? 'border-[var(--accent-color)]' : 'border-transparent hover:border-white'}`} />
      </button>
    );

    return (
      <div className="w-[420px] flex flex-col pointer-events-auto select-none">
        {title}
        <TabBar tabs={['COLORS']} active="COLORS" onSelect={() => {}} />

        <div className="flex flex-col gap-[4px] mt-[4px] max-h-[calc(100vh-520px)] overflow-y-auto styled-scrollbar">
          <Section title="COLORS" open={isOpen('colors', true)} onToggle={() => toggle('colors', true)}>
            <div className="grid grid-cols-2 gap-[6px]">
              {swatchButton(colorTarget === 'primary', () => setColorTarget('primary'), primaryHex, 'Primary')}
              {swatchButton(
                colorTarget === 'secondary',
                () => setColorTarget('secondary'),
                mixType === 'mixB' ? `linear-gradient(135deg, ${primaryHex} 0%, ${secondaryHex} 100%)` : secondaryHex,
                isHairCat ? 'Highlight' : 'Secondary',
              )}
            </div>
          </Section>

          <Section
            title="PICK COLOR"
            open={isOpen('palette', true)}
            onToggle={() => toggle('palette', true)}
            right={<span className="font-np font-semibold not-italic text-[13px] text-black/50">#{currentSelectedColorIndex}</span>}
          >
            <div className="grid grid-cols-8 gap-[5px]">
              {palette.map((hex, idx) => {
                const isActive = currentSelectedColorIndex === idx;
                return (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => handleSelectColor(idx)}
                    title={`Color #${idx}`}
                    className={`aspect-square w-full cursor-pointer relative transition-transform ${isActive ? 'z-10' : 'hover:scale-110 hover:z-20'}`}
                    style={{ backgroundColor: hex }}
                  >
                    <span className={`absolute inset-0 border-2 ${isActive ? 'border-white' : 'border-black/30'}`} />
                  </button>
                );
              })}
            </div>
          </Section>

          <Section title="COLOR MIXING TYPE" open={isOpen('mix', false)} onToggle={() => toggle('mix', false)}>
            <div className="grid grid-cols-2 gap-[6px]">
              {swatchButton(mixType === 'mixA', () => setMixType('mixA'), primaryHex, 'Color Mix A')}
              {swatchButton(mixType === 'mixB', () => setMixType('mixB'), `linear-gradient(135deg, ${primaryHex} 0%, ${secondaryHex} 100%)`, 'Color Mix B')}
            </div>
          </Section>

          {overlayKey && (
            <Section
              title="OPACITY"
              open={isOpen('opacity', true)}
              onToggle={() => toggle('opacity', true)}
              right={<span className="font-np font-semibold not-italic text-[13px] text-black/50">{Math.round(opacityVal * 100)}%</span>}
            >
              <div className="flex items-center gap-3 px-1 py-2">
                <span className="font-np font-bold italic text-[15px] text-white/80">MIN</span>
                <input
                  type="range"
                  min="0"
                  max="1"
                  step="0.05"
                  value={opacityVal}
                  onChange={(e) => handleOpacityChange(parseFloat(e.target.value))}
                  className="flex-1 h-[4px] appearance-none cursor-pointer"
                  style={{
                    background: `linear-gradient(to right, #ffffff ${opacityVal * 100}%, rgba(255,255,255,0.2) ${opacityVal * 100}%)`
                  }}
                />
                <span className="font-np font-bold italic text-[15px] text-white/80">MAX</span>
              </div>
            </Section>
          )}
        </div>
      </div>
    );
  }

  if (!activeCategory || !activeItem) return null;

  const type = wornType;
  const itemId = wornId;

  const handleUpdateTexture = (textureId: number) => {
    if (type === 'component') {
      Nui.post('appearance_change_component', {
        component_id: itemId,
        drawable: activeItem.drawable,
        texture: textureId,
      });
    } else {
      Nui.post('appearance_change_prop', {
        prop_id: itemId,
        drawable: activeItem.drawable,
        texture: textureId,
      });
    }
    if (onTextureSelect) {
      onTextureSelect(textureId);
    }
  };

  const renderTextureGrid = (
    kind: ItemKind,
    id: number,
    drawable: number,
    current: number,
    max: number | null,
    onPick: (tex: number) => void,
  ) => {
    if (drawable === undefined || drawable < 0) {
      return <div className="py-4 text-center font-np font-semibold italic text-[15px] text-white/50 uppercase">Nothing equipped</div>;
    }
    const count = max === null ? 1 : Math.max(max + 1, 1);
    const price = getItemPrice(prices, !!isFree, kind, id, drawable);
    return (
      <div className="grid grid-cols-3 gap-[6px]">
        {Array.from({ length: count }).map((_, tex) => (
          <ItemCard
            key={`${kind}-${id}-${drawable}-${tex}`}
            name={`Texture ${tex + 1}`}
            price={price}
            isFree={isFree}
            active={current === tex}
            onClick={() => onPick(tex)}
          >
            <ItemImage
              candidates={getClothingImageCandidates(images, kind, id, drawable, tex, gender)}
              fallback={<span className="font-np font-bold italic text-[30px] text-white/40">{tex + 1}</span>}
            />
          </ItemCard>
        ))}
      </div>
    );
  };

  const renderRelated = (tab: RelatedTab) => {
    const settings =
      tab.type === 'component'
        ? (appearanceSettings?.components || []).find((c: any) => c?.component_id === tab.id)
        : (appearanceSettings?.props || []).find((p: any) => p?.prop_id === tab.id);
    const max = typeof settings?.drawable?.max === 'number' ? settings.drawable.max : 20;
    const min = tab.type === 'prop' ? -1 : 0;
    const drawables = Array.from({ length: Math.max(max - min + 1, 1) }).map((_, i) => i + min);
    const wornTexture = relatedWorn?.texture ?? 0;
    const listKey = `${tab.label}-list`;
    const texKey = `${tab.label}-tex`;

    return (
      <>
        <Section title={tab.label} open={isOpen(listKey, true)} onToggle={() => toggle(listKey, true)}>
          <div className="grid grid-cols-3 gap-[6px]">
            {drawables.map((d) => (
              <ItemCard
                key={`${tab.label}-${d}`}
                name={d < 0 ? 'None' : `${titleCase(tab.singular)} ${d}`}
                price={getItemPrice(prices, !!isFree, tab.type, tab.id, d)}
                isFree={isFree}
                active={relatedDrawable === d}
                onClick={() => onApplyItem?.(tab.type, tab.id, d, 0)}
              >
                <ItemImage
                  candidates={d < 0 ? [] : getClothingImageCandidates(images, tab.type, tab.id, d, 0, gender)}
                  fallback={<span className="text-white/40">{getCategoryLucideIcon(tab.label, 'w-9 h-9')}</span>}
                />
              </ItemCard>
            ))}
          </div>
        </Section>
        <Section title={`${tab.singular} TEXTURES`} open={isOpen(texKey, false)} onToggle={() => toggle(texKey, false)}>
          {renderTextureGrid(tab.type, tab.id, relatedDrawable as number, wornTexture, relatedTextureMax, (tex) =>
            onApplyItem?.(tab.type, tab.id, relatedDrawable as number, tex),
          )}
        </Section>
      </>
    );
  };

  return (
    <div className="w-[420px] flex flex-col pointer-events-auto select-none">
      {title}
      <TabBar tabs={['STYLES', ...relatedTabs.map((t) => t.label)]} active={activeTab} onSelect={setActiveTab} />

      <div className="flex flex-col gap-[4px] mt-[4px] max-h-[calc(100vh-520px)] overflow-y-auto styled-scrollbar">
        {related ? (
          renderRelated(related)
        ) : (
          <Section title="TEXTURES" open={isOpen('textures', true)} onToggle={() => toggle('textures', true)}>
            {renderTextureGrid(type, itemId, activeItem.drawable, activeItem.texture || 0, textureMax, handleUpdateTexture)}
          </Section>
        )}
      </div>
    </div>
  );
}
