import { create } from 'zustand';
import type { TargetData } from './types';

interface TargetState {
  visible: boolean;
  setVisible: (value: boolean) => void;
  target: TargetData | null;
  setTarget: (value: TargetData | null) => void;
  hasCursor: boolean;
  setHasCursor: (value: boolean) => void;
  startCoords: { x: number; y: number };
  setStartCoords: (value: { x: number; y: number }) => void;
}

export const useTargetStore = create<TargetState>((set) => ({
  visible: false,
  setVisible: (value) => set(() => (value ? { visible: value } : { visible: value, target: null })),
  target: null,
  setTarget: (value) => set({ target: value }),
  hasCursor: false,
  setHasCursor: (value) => set({ hasCursor: value }),
  startCoords: { x: 0.5, y: 0.5 },
  setStartCoords: (value) => set({ startCoords: value }),
}));
