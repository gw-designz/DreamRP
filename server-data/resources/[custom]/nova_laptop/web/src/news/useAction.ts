import { useCallback, useEffect, useRef, useState } from 'react';
import { action } from '../api';
import type { Response } from '../types';

/** Loads one server action when mounted (and when `key` changes); `reload` asks again. */
export function useAction<T>(name: string, pick: (reply: Response) => T, key: unknown = null) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const pickRef = useRef(pick);
  pickRef.current = pick;
  const generation = useRef(0);
  const reload = useCallback(async () => {
    const mine = ++generation.current;
    setLoading(true);
    const reply = await action(name);
    if (mine !== generation.current) return;
    setLoading(false);
    if (reply.ok) { setData(pickRef.current(reply)); setError(''); }
    else setError(reply.error || 'Could not load this.');
  }, [name]);
  useEffect(() => { void reload(); }, [reload, key]);
  return { data, setData, error, loading, reload };
}
