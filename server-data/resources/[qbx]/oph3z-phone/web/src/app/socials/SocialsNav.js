import { createContext, useContext } from 'react';

export const SocialsNavContext = createContext(null);

const noop = () => {};
const FALLBACK = { openPost: noop, openProfile: noop, openTopic: noop, openFollowList: noop };

export const useSocialsNav = () => useContext(SocialsNavContext) || FALLBACK;
