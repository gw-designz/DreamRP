import { useEffect, useRef } from 'react';

export function useAutoRefresh(enabled: boolean, update: () => Promise<void>, eventType?: string, interval = 4000) {
  const running = useRef(false), lastStarted = useRef(0);
  useEffect(() => {
    if (!enabled) return;
    let stopped = false, timer = 0;
    const schedule = (delay = 0) => {
      clearTimeout(timer);
      if (!stopped && !document.hidden) timer = window.setTimeout(tick, Math.max(delay, lastStarted.current + 750 - Date.now(), 0));
    };
    const tick = async () => {
      if (stopped || document.hidden) return;
      if (running.current) { schedule(750); return; }
      running.current = true; lastStarted.current = Date.now();
      try { await update(); }
      finally { running.current = false; schedule(interval); }
    };
    const resume = () => schedule();
    const receive = (event: MessageEvent) => { if (eventType && event.data?.type === eventType) schedule(); };
    schedule();
    document.addEventListener('visibilitychange', resume);
    window.addEventListener('focus', resume);
    window.addEventListener('online', resume);
    window.addEventListener('message', receive);
    return () => {
      stopped = true; clearTimeout(timer);
      document.removeEventListener('visibilitychange', resume);
      window.removeEventListener('focus', resume);
      window.removeEventListener('online', resume);
      window.removeEventListener('message', receive);
    };
  }, [enabled, update, eventType, interval]);
}
