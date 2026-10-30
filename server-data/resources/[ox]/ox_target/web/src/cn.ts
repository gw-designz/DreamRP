import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

/**
 * Same helper the original interface uses (`twMerge(clsx(...))`).
 * It matters: the reticle relies on tailwind-merge dropping `bg-white/50`
 * in favour of `bg-primary`, which plain class concatenation would not do.
 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
