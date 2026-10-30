import React from 'react';
import {
  Shirt,
  Scissors,
  Eye,
  User,
  Sparkles,
  Sun,
  CircleDot,
  Heart,
  Crown,
  Glasses,
  Watch,
  Backpack,
  Ghost,
  Ear,
  Layers,
  Footprints,
  ScanFace,
  Users,
  Smile,
  Paintbrush,
  Tag,
  Hand,
  Gem,
  Hourglass,
} from 'lucide-react';
import { GameIcon } from './GameIcon';
import {
  IconBracelet,
  IconHeadGoggles,
  IconLongSleeve,
  IconMitten,
  IconScarf,
  IconShorts,
  IconSneaker,
  IconTank,
  IconTee,
  IconWristwatch,
} from './NpIcons';

export const LucidePants = ({ className = 'w-6 h-6' }: { className?: string }) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={className}>
    <path d="M4 2h16v3l-2 15h-4l-2-10-2 10H6L4 5z" />
  </svg>
);

export const LucideKevlarVest = ({ className = 'w-6 h-6' }: { className?: string }) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={className}>
    <path d="M6 3h3.5l1.5 3h2l1.5-3H18l2 6-2 1v11H6V10L4 9z" />
    <path d="M8 12h8" />
    <path d="M8 16h8" />
  </svg>
);

export const LucideTacticalHarness = ({ className = 'w-6 h-6' }: { className?: string }) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={className}>
    <path d="M6 3v5l-2 4v9" />
    <path d="M18 3v5l2 4v9" />
    <path d="M6 9h12" />
    <path d="M6 14h12" />
    <circle cx="12" cy="11.5" r="2" />
    <path d="M12 13.5v7.5" />
  </svg>
);

// The shop menu's own glyphs, for the categories it shows.
const NP_ICONS: Record<string, React.ComponentType<{ className?: string }>> = {
  'OUTFITS': IconTee,
  'SAVED OUTFITS': IconTee,
  'CLOTHING': IconTee,
  'UPPER BODY ACCESSORIES': IconScarf,
  'HAND & WRIST ACCESSORIES': IconMitten,
  'HEAD ACCESSORIES': IconHeadGoggles,
  'TOPS': IconLongSleeve,
  'UNDERSHIRTS': IconTank,
  'BOTTOMS': IconShorts,
  'SHOES': IconSneaker,
  'GLOVES': IconMitten,
  'WATCHES': IconWristwatch,
  'BRACELETS': IconBracelet,
};

// Solid glyphs (public/game-icons) for the categories that have one; the lucide outlines below
// are the fallback for everything else.
const SOLID_ICONS: Record<string, string> = {
  'OUTFITS': 'hanger',
  'SAVED OUTFITS': 'hanger',
  'CLOTHING': 't-shirt',
  'UPPER BODY ACCESSORIES': 'chest-armor',
  'HAND & WRIST ACCESSORIES': 'gloves',
  'HEAD ACCESSORIES': 'fedora',
  'TOPS': 't-shirt',
  'UNDERSHIRTS': 't-shirt',
  'BOTTOMS': 'trousers',
  'SHOES': 'boots',
  'BODY ARMOR': 'chest-armor',
  'BAGS & PARACHUTES': 'backpack',
  'GLOVES': 'gloves',
  'WATCHES': 'watch',
  'BRACELETS': 'gems',
  'MASKS': 'domino-mask',
  'HATS': 'fedora',
  'GLASSES': 'sunglasses',
  'FACIAL HAIR': 'beard',
  'EYEBROWS': 'eyelashes',
  'MAKEUP': 'lipstick',
  'BLUSH': 'lipstick',
  'LIPSTICK': 'lipstick',
  'NOSE': 'nose-front',
  'AGEING': 'hourglass',
  'SUN DAMAGE': 'barbed-sun',
  'LEFT ARM': 'arm',
  'RIGHT ARM': 'arm',
  'TORSO': 'body-balance',
  'HEAD BLEND': 'person',
  'PED MODELS': 'person',
};

export const getCategoryLucideIcon = (label: string, className: string = 'w-6 h-6') => {
  const l = (label || '').toUpperCase().trim();

  const NpIcon = NP_ICONS[l];
  if (NpIcon) return <NpIcon className={className} />;
  if (SOLID_ICONS[l]) return <GameIcon name={SOLID_ICONS[l]} className={className} />;

  if (l === 'OUTFITS' || l === 'SAVED OUTFITS') return <Layers className={className} />;
  if (l === 'CLOTHING') return <Shirt className={className} />;
  if (l === 'UPPER BODY ACCESSORIES') return <LucideTacticalHarness className={className} />;
  if (l === 'HAND & WRIST ACCESSORIES') return <Watch className={className} />;
  if (l === 'HEAD ACCESSORIES') return <Crown className={className} />;
  if (l === 'STYLES' || l === 'HAIRSTYLE') return <Scissors className={className} />;
  if (l === 'FACIAL HAIR' || l === 'BEARD') return <Smile className={className} />;
  if (l === 'EYEBROWS') return <Eye className={className} />;
  if (l === 'CHEST HAIR') return <User className={className} />;

  if (l.includes('TOP') || l.includes('SHIRT') || l.includes('UNDER')) return <Shirt className={className} />;
  if (l.includes('BOTTOM') || l.includes('LEG')) return <LucidePants className={className} />;
  if (l.includes('SHOE') || l.includes('FOOT')) return <Footprints className={className} />;
  if (l.includes('ARMOR')) return <LucideKevlarVest className={className} />;
  if (l.includes('BAG') || l.includes('PARACHUTE')) return <Backpack className={className} />;
  if (l.includes('DECAL')) return <Tag className={className} />;
  if (l.includes('GLOVE')) return <Hand className={className} />;
  if (l.includes('WATCH')) return <Watch className={className} />;
  if (l.includes('BRACELET')) return <Gem className={className} />;
  if (l.includes('MASK')) return <Ghost className={className} />;
  if (l.includes('HAT')) return <Crown className={className} />;
  if (l.includes('GLASS')) return <Glasses className={className} />;
  if (l.includes('EAR')) return <Ear className={className} />;
  if (l.includes('HEAD BLEND') || l.includes('BLEND')) return <Users className={className} />;
  if (l.includes('EYE COLOR')) return <Eye className={className} />;
  if (l.includes('FEATURE')) return <ScanFace className={className} />;
  if (l.includes('NOSE')) return <ScanFace className={className} />;
  if (l.includes('BROW')) return <Eye className={className} />;
  if (l.includes('EYE')) return <Eye className={className} />;
  if (l.includes('CHEEK')) return <Smile className={className} />;
  if (l.includes('LIP') || l.includes('JAW')) return <Heart className={className} />;
  if (l.includes('CHIN') || l.includes('NECK')) return <User className={className} />;
  if (l.includes('BLEMISH') || l.includes('MOLE') || l.includes('FRECKLE')) return <CircleDot className={className} />;
  if (l.includes('AGE')) return <Hourglass className={className} />;
  if (l.includes('COMPLEXION') || l.includes('SUN')) return <Sun className={className} />;
  if (l.includes('MAKEUP') || l.includes('BLUSH') || l.includes('LIPSTICK')) return <Sparkles className={className} />;
  if (l.includes('HAIR') || l.includes('STYLE')) return <Scissors className={className} />;
  if (l.includes('CHEST')) return <User className={className} />;
  if (l.includes('ZONE_HEAD') || l === 'HEAD') return <User className={className} />;
  if (l.includes('ZONE_TORSO') || l.includes('TORSO')) return <LucideKevlarVest className={className} />;
  if (l.includes('ARM')) return <Paintbrush className={className} />;
  if (l.includes('PED') || l.includes('MODEL')) return <User className={className} />;

  return <Shirt className={className} />;
};
