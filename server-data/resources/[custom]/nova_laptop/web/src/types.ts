export type Settings = { theme: 'light' | 'dark'; wallpaper: 'bloom' | 'dusk' | 'aurora'; accent: 'red' | 'blue' | 'violet' | 'mint'; sounds: boolean };
export type AppInfo = { id: string; name: string; title: string; icon: string };
export type LaptopData = { player: { name: string; serverId: number }; serverName: string; deviceName: string; settings: Settings; framework: string; session?: number };
export type WindowState = { id: string; x: number; y: number; width: number; height: number; z: number; minimized: boolean; maximized: boolean };
// Each app reads the fields its own action returns.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Response = { ok: boolean; error?: string; settings?: Settings; [field: string]: any };
declare global { interface Window { GetParentResourceName?: () => string; NOVA_DUI?: boolean } }
