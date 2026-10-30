import React from 'react';
import Nui from '../Nui';
import { getCategoryLucideIcon } from './CategoryIcons';
import { IconTile, PageHeader } from './ui';
import { ChevronLeft, ChevronRight } from 'lucide-react';

const FEATURE_NAMES: Record<string, string> = {
  'shapeFirst': 'Father Face Shape',
  'shapeSecond': 'Mother Face Shape',
  'skinFirst': 'Father Skin Tone',
  'skinSecond': 'Mother Skin Tone',
  'shapeMix': 'Face Shape Mix',
  'skinMix': 'Skin Tone Mix',
  'noseWidth': 'Nose Width',
  'nosePeakHigh': 'Nose Peak Height',
  'nosePeakSize': 'Nose Peak Size',
  'noseBoneHigh': 'Nose Bone Height',
  'nosePeakLowering': 'Nose Peak Lowering',
  'noseBoneTwist': 'Nose Bone Twist',
  'eyeBrownHigh': 'Brow Height',
  'eyeBrownForward': 'Brow Depth',
  'cheeksBoneHigh': 'Cheekbone Height',
  'cheeksBoneWidth': 'Cheekbone Width',
  'cheeksWidth': 'Cheek Width',
  'eyesOpening': 'Eye Opening',
  'lipsThickness': 'Lip Thickness',
  'jawBoneWidth': 'Jaw Width',
  'jawBoneBackSize': 'Jaw Depth',
  'chinBoneLowering': 'Chin Height',
  'chinBoneLenght': 'Chin Length',
  'chinBoneSize': 'Chin Width',
  'chinHole': 'Chin Hole',
  'neckThickness': 'Neck Thickness',
  'blemishes': 'Blemishes',
  'beard': 'Facial Hair',
  'eyebrows': 'Eyebrows',
  'ageing': 'Ageing',
  'makeUp': 'Makeup',
  'blush': 'Blush',
  'complexion': 'Complexion',
  'sunDamage': 'Sun Damage',
  'lipstick': 'Lipstick',
  'moleAndFreckles': 'Moles & Freckles',
  'chestHair': 'Chest Hair',
  'bodyBlemishes': 'Body Blemishes',
};

const FEATURE_LABELS: Record<string, { title: string; minLabel: string; maxLabel: string }> = {
  'noseWidth': { title: 'WIDTH', minLabel: 'THIN', maxLabel: 'WIDE' },
  'nosePeakHigh': { title: 'HEIGHT', minLabel: 'DOWN', maxLabel: 'UP' },
  'nosePeakSize': { title: 'LENGTH', minLabel: 'SHORT', maxLabel: 'LONG' },
  'noseBoneHigh': { title: 'BONE HEIGHT', minLabel: 'LOW', maxLabel: 'HIGH' },
  'nosePeakLowering': { title: 'PEAK LOWERING', minLabel: 'DOWN', maxLabel: 'UP' },
  'noseBoneTwist': { title: 'TWIST', minLabel: 'LEFT', maxLabel: 'RIGHT' },
  'eyeBrownHigh': { title: 'BROW HEIGHT', minLabel: 'LOW', maxLabel: 'HIGH' },
  'eyeBrownForward': { title: 'BROW DEPTH', minLabel: 'OUT', maxLabel: 'IN' },
  'cheeksBoneHigh': { title: 'CHEEKBONE HEIGHT', minLabel: 'LOW', maxLabel: 'HIGH' },
  'cheeksBoneWidth': { title: 'CHEEKBONE WIDTH', minLabel: 'THIN', maxLabel: 'WIDE' },
  'cheeksWidth': { title: 'CHEEK WIDTH', minLabel: 'THIN', maxLabel: 'WIDE' },
  'eyesOpening': { title: 'EYE OPENING', minLabel: 'CLOSED', maxLabel: 'OPEN' },
  'lipsThickness': { title: 'LIP THICKNESS', minLabel: 'THIN', maxLabel: 'THICK' },
  'jawBoneWidth': { title: 'JAW WIDTH', minLabel: 'THIN', maxLabel: 'WIDE' },
  'jawBoneBackSize': { title: 'JAW DEPTH', minLabel: 'SHORT', maxLabel: 'LONG' },
  'chinBoneLowering': { title: 'CHIN HEIGHT', minLabel: 'DOWN', maxLabel: 'UP' },
  'chinBoneLenght': { title: 'CHIN LENGTH', minLabel: 'SHORT', maxLabel: 'LONG' },
  'chinBoneSize': { title: 'CHIN WIDTH', minLabel: 'SMALL', maxLabel: 'LARGE' },
  'chinHole': { title: 'CHIN HOLE', minLabel: 'NONE', maxLabel: 'DEEP' },
  'neckThickness': { title: 'NECK THICKNESS', minLabel: 'THIN', maxLabel: 'THICK' },
  'shapeFirst': { title: 'FATHER FACE SHAPE', minLabel: 'BENJAMIN', maxLabel: 'HANNAH' },
  'shapeSecond': { title: 'MOTHER FACE SHAPE', minLabel: 'BENJAMIN', maxLabel: 'HANNAH' },
  'skinFirst': { title: 'FATHER SKIN TONE', minLabel: 'LIGHT', maxLabel: 'DARK' },
  'skinSecond': { title: 'MOTHER SKIN TONE', minLabel: 'LIGHT', maxLabel: 'DARK' },
  'shapeMix': { title: 'FACE SHAPE MIX', minLabel: 'FATHER', maxLabel: 'MOTHER' },
  'skinMix': { title: 'SKIN TONE MIX', minLabel: 'FATHER', maxLabel: 'MOTHER' },
  'blemishes': { title: 'BLEMISHES', minLabel: 'NONE', maxLabel: 'MAX' },
  'beard': { title: 'FACIAL HAIR', minLabel: 'CLEAN', maxLabel: 'FULL' },
  'eyebrows': { title: 'EYEBROWS', minLabel: 'CLEAN', maxLabel: 'THICK' },
  'ageing': { title: 'AGEING', minLabel: 'YOUNG', maxLabel: 'OLD' },
  'makeUp': { title: 'MAKEUP', minLabel: 'NONE', maxLabel: 'HEAVY' },
  'blush': { title: 'BLUSH', minLabel: 'NONE', maxLabel: 'FULL' },
  'complexion': { title: 'COMPLEXION', minLabel: 'CLEAR', maxLabel: 'HEAVY' },
  'sunDamage': { title: 'SUN DAMAGE', minLabel: 'NONE', maxLabel: 'HEAVY' },
  'lipstick': { title: 'LIPSTICK', minLabel: 'NONE', maxLabel: 'FULL' },
  'moleAndFreckles': { title: 'MOLES & FRECKLES', minLabel: 'NONE', maxLabel: 'HEAVY' },
  'chestHair': { title: 'CHEST HAIR', minLabel: 'CLEAN', maxLabel: 'FULL' },
  'bodyBlemishes': { title: 'BODY BLEMISHES', minLabel: 'NONE', maxLabel: 'HEAVY' },
};

const SUBCATEGORIES_BY_TAB: Record<string, { label: string }[]> = {
  'FACE ADJUSTMENTS': [
    { label: 'NOSE' },
    { label: 'BROW' },
    { label: 'EYES' },
    { label: 'CHEEKS' },
    { label: 'LIPS & JAW' },
    { label: 'CHIN & NECK' }
  ],
  'FACE & BODY': [
    { label: 'HEAD BLEND' },
    { label: 'EYE COLOR' },
    { label: 'FACE FEATURES' }
  ],
  'OVERLAYS': [
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
    { label: 'CHEST HAIR' }
  ],
  'HAIR': [
    { label: 'STYLES' },
    { label: 'FACIAL HAIR' },
    { label: 'EYEBROWS' },
    { label: 'CHEST HAIR' }
  ]
};

export default function Sliders({
  navPath,
  setNavPath,
  activeCategory,
  appearanceData,
  setAppearanceData,
}: {
  navPath: string[];
  setNavPath: (path: string[]) => void;
  activeCategory: string;
  appearanceData: any;
  setAppearanceData: React.Dispatch<React.SetStateAction<any>>;
}) {


  const handleFeatureChange = (key: string, value: number) => {
    setAppearanceData((prev: any) => ({
      ...prev,
      faceFeatures: {
        ...(prev?.faceFeatures || {}),
        [key]: value
      }
    }));
    Nui.post('appearance_change_face_feature', { key, value });
  };

  const handleHeadBlendChange = (key: string, val: number) => {
    const currentBlend = appearanceData?.headBlend || {
      shapeFirst: 21,
      shapeSecond: 22,
      shapeThird: 0,
      skinFirst: 21,
      skinSecond: 22,
      skinThird: 0,
      shapeMix: 0.5,
      skinMix: 0.5,
      thirdMix: 0
    };
    const updated = { ...currentBlend, [key]: val };
    setAppearanceData((prev: any) => ({
      ...prev,
      headBlend: updated
    }));
    Nui.post('appearance_change_head_blend', updated);
  };

  const handleHeadOverlayChange = (key: string, value: any) => {
    const updatedOverlay = {
      style: value.style,
      opacity: value.opacity,
      color: value.color || 0,
      secondColor: value.secondColor || 0
    };
    setAppearanceData((prev: any) => ({
      ...prev,
      headOverlays: {
        ...(prev?.headOverlays || {}),
        [key]: updatedOverlay
      }
    }));
    Nui.post('appearance_change_head_overlay', {
       key, 
       style: value.style, 
       opacity: value.opacity, 
       color: value.color || 0, 
       secondColor: value.secondColor || 0
    });
  };

  const mainTab = navPath[0];
  let itemsToRender: string[] = [];
  
  if (mainTab === 'FACE ADJUSTMENTS') {
    if (activeCategory === 'NOSE') itemsToRender = ['noseWidth', 'nosePeakHigh', 'nosePeakSize', 'noseBoneHigh', 'nosePeakLowering', 'noseBoneTwist'];
    else if (activeCategory === 'BROW') itemsToRender = ['eyeBrownHigh', 'eyeBrownForward'];
    else if (activeCategory === 'EYES') itemsToRender = ['eyesOpening'];
    else if (activeCategory === 'CHEEKS') itemsToRender = ['cheeksBoneHigh', 'cheeksBoneWidth', 'cheeksWidth'];
    else if (activeCategory === 'LIPS & JAW' || activeCategory === 'LIPS') itemsToRender = ['lipsThickness', 'jawBoneWidth', 'jawBoneBackSize'];
    else if (activeCategory === 'CHIN & NECK' || activeCategory === 'CHIN') itemsToRender = ['chinBoneLowering', 'chinBoneLenght', 'chinBoneSize', 'chinHole', 'neckThickness'];
    else itemsToRender = ['noseWidth', 'nosePeakHigh', 'nosePeakSize', 'noseBoneHigh', 'nosePeakLowering', 'noseBoneTwist'];
  } else if (mainTab === 'OVERLAYS' || mainTab === 'HAIR') {
    if (activeCategory === 'BLEMISHES') itemsToRender = ['blemishes'];
    else if (activeCategory === 'AGEING') itemsToRender = ['ageing'];
    else if (activeCategory === 'COMPLEXION') itemsToRender = ['complexion'];
    else if (activeCategory === 'SUN DAMAGE') itemsToRender = ['sunDamage'];
    else if (activeCategory === 'MOLES & FRECKLES') itemsToRender = ['moleAndFreckles'];
    else if (activeCategory === 'BODY BLEMISHES') itemsToRender = ['bodyBlemishes'];
    else if (activeCategory === 'MAKEUP') itemsToRender = ['makeUp'];
    else if (activeCategory === 'BLUSH') itemsToRender = ['blush'];
    else if (activeCategory === 'LIPSTICK') itemsToRender = ['lipstick'];
    else if (activeCategory === 'FACIAL HAIR') itemsToRender = ['beard'];
    else if (activeCategory === 'EYEBROWS') itemsToRender = ['eyebrows'];
    else if (activeCategory === 'CHEST HAIR') itemsToRender = ['chestHair'];
    else itemsToRender = ['blemishes', 'ageing', 'complexion', 'sunDamage', 'moleAndFreckles', 'bodyBlemishes', 'makeUp', 'blush', 'lipstick', 'beard', 'eyebrows', 'chestHair'];
  } else if (mainTab === 'FACE & BODY' && activeCategory === 'HEAD BLEND') {
    itemsToRender = ['shapeFirst', 'shapeSecond', 'shapeMix', 'skinFirst', 'skinSecond', 'skinMix'];
  }

  const subcategoryList = SUBCATEGORIES_BY_TAB[mainTab] || [];

  return (
    <div className="flex flex-col pointer-events-auto select-none relative z-10 text-white">
      <PageHeader navPath={navPath} setNavPath={setNavPath} />

      <div className="flex gap-[4px]">
        {subcategoryList.length > 0 && (
          <div className="flex flex-col gap-[4px]">
            {subcategoryList.map(sub => {
              const isSubActive = activeCategory === sub.label || (navPath.length === 1 && sub.label === subcategoryList[0]?.label);
              return (
                <IconTile key={sub.label} title={sub.label} active={isSubActive} onClick={() => setNavPath([mainTab, sub.label])}>
                  {getCategoryLucideIcon(sub.label, 'w-6 h-6')}
                </IconTile>
              );
            })}
          </div>
        )}

        <div className="w-[492px] ml-[6px] flex flex-col gap-[6px] h-fit max-h-[calc(100vh-250px)] overflow-y-auto styled-scrollbar pr-[6px]">
          {itemsToRender.length === 0 && (
            <div className="np-panel font-np font-bold italic text-[20px] text-white/50 text-center py-10 uppercase">NO OPTIONS AVAILABLE FOR {activeCategory}</div>
          )}
          
          {itemsToRender.map(key => {
            let value = 0;
            let min = -1.0;
            let max = 1.0;
            let step = 0.05;
            let isOverlay = false;
            let isHeadBlend = false;
            let isHeadBlendShapeOrSkin = false;

            if (mainTab === 'FACE ADJUSTMENTS') {
               value = appearanceData?.faceFeatures?.[key] || 0;
            } else if (mainTab === 'FACE & BODY' && activeCategory === 'HEAD BLEND') {
               isHeadBlend = true;
               value = appearanceData?.headBlend?.[key] ?? (key.includes('Mix') ? 0.5 : 21);
               if (key.includes('Mix')) {
                 min = 0.0; max = 1.0; step = 0.01;
               } else {
                 isHeadBlendShapeOrSkin = true;
                 min = 1; max = 45; step = 1;
               }
            } else if (mainTab === 'OVERLAYS' || mainTab === 'HAIR' || ['beard', 'eyebrows', 'chestHair', 'blemishes', 'ageing', 'complexion', 'sunDamage', 'moleAndFreckles', 'bodyBlemishes', 'makeUp', 'blush', 'lipstick'].includes(key)) {
               isOverlay = true;
               value = appearanceData?.headOverlays?.[key]?.style || 0;
               min = 0; max = 25; step = 1;
            }

            const currentDisplayVal = isHeadBlendShapeOrSkin ? Math.max(1, Math.round(value)) : value;

            const handleUpdate = (displayVal: number) => {
              const clampedDisplay = Math.min(Math.max(displayVal, min), max);
              if (isOverlay) {
                const currentOv = appearanceData?.headOverlays?.[key] || {};
                handleHeadOverlayChange(key, {
                  style: Math.round(clampedDisplay),
                  opacity: currentOv.opacity !== undefined ? currentOv.opacity : 1.0,
                  color: currentOv.color || 0,
                  secondColor: currentOv.secondColor || 0
                });
              } else if (isHeadBlend) {
                if (isHeadBlendShapeOrSkin) {
                  handleHeadBlendChange(key, Math.round(clampedDisplay));
                } else {
                  const finalVal = parseFloat(clampedDisplay.toFixed(2));
                  handleHeadBlendChange(key, finalVal);
                }
              } else {
                handleFeatureChange(key, parseFloat(clampedDisplay.toFixed(2)));
              }
            };

            const handleStep = (dir: number) => {
              let delta = 1;
              if (isHeadBlend && key.includes('Mix')) delta = 0.05;
              else if (!isHeadBlend && !isOverlay) delta = 0.05;
              handleUpdate(currentDisplayVal + dir * delta);
            };

            const displayValue = isHeadBlendShapeOrSkin 
              ? Math.round(currentDisplayVal)
              : isHeadBlend && key.includes('Mix')
              ? value.toFixed(2)
              : isOverlay 
              ? Math.round(value)
              : value.toFixed(2);

            const labelData = FEATURE_LABELS[key] || {
              title: (FEATURE_NAMES[key] || key.replace(/([A-Z])/g, ' $1')).toUpperCase(),
              minLabel: 'MIN',
              maxLabel: 'MAX'
            };

            const valToCalc = isHeadBlendShapeOrSkin ? currentDisplayVal : value;
            const pct = Math.min(Math.max(((valToCalc - min) / (max - min)) * 100, 0), 100);

            return (
              <div key={key} className="flex flex-col">
                <div className="h-[28px] bg-white text-black px-3 flex justify-between items-center">
                  <span className="font-np font-bold italic text-[16px] uppercase leading-none">{labelData.title}</span>

                  <div className="flex items-center gap-[3px]">
                    <button
                      type="button"
                      onClick={() => handleStep(-1)}
                      className="w-5 h-5 bg-black text-white hover:bg-zinc-700 flex items-center justify-center transition-colors cursor-pointer"
                      title="Decrease"
                    >
                      <ChevronLeft className="w-4 h-4" strokeWidth={3} />
                    </button>
                    <span className="min-w-[40px] h-5 flex items-center justify-center font-np font-bold text-[14px] px-1.5 bg-black text-white leading-none">
                      {displayValue}
                    </span>
                    <button
                      type="button"
                      onClick={() => handleStep(1)}
                      className="w-5 h-5 bg-black text-white hover:bg-zinc-700 flex items-center justify-center transition-colors cursor-pointer"
                      title="Increase"
                    >
                      <ChevronRight className="w-4 h-4" strokeWidth={3} />
                    </button>
                  </div>
                </div>

                <div className="np-panel px-3 py-3.5 flex items-center justify-between gap-3">
                  <span className="font-np font-bold italic text-[17px] text-white/85 uppercase w-20 text-right flex-shrink-0 leading-none">
                    {labelData.minLabel}
                  </span>

                  <input 
                    type="range" 
                    min={min} 
                    max={max} 
                    step={step} 
                    value={currentDisplayVal}
                    onChange={(e) => handleUpdate(parseFloat(e.target.value))}
                    className="flex-1 h-[4px] appearance-none cursor-pointer"
                    style={{
                      background: `linear-gradient(to right, #ffffff ${pct}%, rgba(255,255,255,0.2) ${pct}%)`
                    }}
                  />

                  <span className="font-np font-bold italic text-[17px] text-white/85 uppercase w-20 text-left flex-shrink-0 leading-none">
                    {labelData.maxLabel}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
