import type { LaptopData, Response } from './types';
import { previewNews } from './news/preview';

const params = new URLSearchParams(window.location.search);
// World mode loads dui.html off screen (a DUI) and paints it on the laptop prop.
export const isDui = window.NOVA_DUI === true || params.get('mode') === 'dui';
// A DUI page may not have GetParentResourceName; nui:// pages are served from https://cfx-nui-<resource>/.
const resourceName = () => window.GetParentResourceName?.() || params.get('res')
  || window.location.hostname.replace(/^cfx-nui-/, '') || 'nova_laptop';
export const isPreview = !isDui && typeof window.GetParentResourceName !== 'function';
const demoDefaults: LaptopData = {
  player: { name: 'Percival Small', serverId: 1 }, serverName: 'Los Santos', deviceName: 'WEAZEL BOOK',
  settings: { theme: 'light', wallpaper: 'bloom', accent: 'red', sounds: true }, framework: 'preview'
};

export function previewData(): LaptopData {
  try {
    const stored = JSON.parse(localStorage.getItem('nova-preview-v1') || 'null');
    return { ...demoDefaults, settings: { ...demoDefaults.settings, ...stored?.settings } };
  } catch { return structuredClone(demoDefaults); }
}

function previewAction(action: string, payload: Record<string, unknown>): Response {
  if (action.startsWith('news')) return previewNews(action, payload);
  const data = previewData();
  if (action === 'settings') data.settings = payload as typeof data.settings;
  localStorage.setItem('nova-preview-v1', JSON.stringify(data));
  return { ok: true, settings: data.settings };
}

export async function nui(endpoint: string, payload: Record<string, unknown> = {}): Promise<Response> {
  if (isPreview) {
    await new Promise(resolve => setTimeout(resolve, 130));
    try { return endpoint === 'action' ? structuredClone(previewAction(payload.action as string, payload.payload as Record<string, unknown>)) : { ok: true }; }
    catch { return { ok: false, error: 'Browser storage is unavailable. Allow local storage to save the preview.' }; }
  }
  const controller = new AbortController();
  const timer = window.setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(`https://${resourceName()}/${endpoint}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload), signal: controller.signal
    });
    if (!response.ok) throw new Error('Connection error');
    return await response.json();
  } catch { return { ok: false, error: 'Connection interrupted. Reopen the laptop to check whether changes saved.' }; }
  finally { window.clearTimeout(timer); }
}

export const action = (name: string, payload: Record<string, unknown> = {}) => nui('action', { action: name, payload });
