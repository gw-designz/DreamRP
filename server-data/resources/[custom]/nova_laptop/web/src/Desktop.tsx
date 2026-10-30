import { useCallback, useEffect, useRef, useState } from 'react';
import type { PointerEvent as ReactPointerEvent } from 'react';
import { action, isDui, isPreview, nui, previewData } from './api';
import { Icon, NovaMark } from './icons';
import { Radial } from './Radial';
import { setSoundsEnabled } from './sounds';
import type { RadialItem } from './Radial';
import { Portal } from './news/Portal';
import { Writer } from './news/Writer';
import { MagazineEditor } from './news/MagazineEditor';
import { Newsstand, IssueReader } from './news/Newsstand';
import { CameraApp } from './news/CameraApp';
import { Trash } from './news/Trash';
import type { Company, Issue, Me } from './news/types';
import type { AppInfo, LaptopData, Settings, WindowState } from './types';

export const APPS: AppInfo[] = [
  { id: 'portal', name: 'LifeInvader', title: 'LifeInvader - Weazel News Staff Portal', icon: 'portal' },
  { id: 'writer', name: 'Weazel Writer', title: 'Weazel Writer - Article Desk', icon: 'writer' },
  { id: 'magazine', name: 'Magazine Editor', title: 'Weazel News - Magazine Editor', icon: 'magazine' },
  { id: 'newsstand', name: 'Newsstand', title: 'LifeInvader Magazine - Newsstand', icon: 'newsstand' },
  { id: 'camera', name: 'Camera', title: 'Weazel Camera - Memory Card', icon: 'camera' },
];
const TRASH: AppInfo = { id: 'trash', name: 'Trash', title: 'Trash', icon: 'trash' };
const ALL = [...APPS, TRASH];
// The full-screen reader's size before zooming: the page and the arrows beside it.
const READER_W = 600, READER_H = 640;
// The screen in page pixels: a menu bar along the top and the dock along the bottom.
const WIDTH = 1280, HEIGHT = 800, MENU = 28, DOCK = 86;
const bounds = (value: number, min: number, max: number) => Math.max(min, Math.min(value, max));
const SIZES: Record<string, [number, number, number, number]> = { // width, height, min width, min height
  portal: [1250, 660, 1000, 520], writer: [1100, 650, 900, 520], magazine: [1270, 680, 1060, 560],
  newsstand: [1190, 670, 820, 520], camera: [900, 580, 640, 420], trash: [760, 480, 560, 360],
};

type MenuItem = { label: string; keys?: string; run: () => void; disabled?: boolean; checked?: boolean } | null;
const nobody: Me = { cid: '', name: '', staff: false, owner: false, onDuty: false, groupId: null,
  perms: { write: false, review: false, edit: false, publish: false, print: false, staff: false, pay: false } };

export function Desktop() {
  const [visible, setVisible] = useState(isPreview);
  const [data, setData] = useState<LaptopData>(previewData);
  const [boot, setBoot] = useState<{ me: Me; company: Company }>({ me: nobody, company: { label: 'News', balance: null, staff: 0, onDuty: 0, groups: 0 } });
  const [windows, setWindows] = useState<WindowState[]>([]);
  const [panel, setPanel] = useState<'spotlight' | 'quick' | 'calendar' | null>(null);
  const [menu, setMenu] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const [clock, setClock] = useState(new Date());
  const [settingsBusy, setSettingsBusy] = useState(false);
  const [toast, setToast] = useState<{ text: string; error: boolean } | null>(null);
  const [booting, setBooting] = useState(false);
  const [reader, setReader] = useState<{ issue: Issue; page: number } | null>(null);
  const [readerZoom, setReaderZoom] = useState(1);
  // The printer's radial menu, opened by the game while the laptop is closed.
  const [radial, setRadial] = useState<RadialItem[] | null>(isPreview && new URLSearchParams(window.location.search).has('radial')
    ? [{ id: 'tray', title: 'Open Printer', icon: 'printer' }, { id: 'copies', title: 'Make Copy(s)', icon: 'copy' }, { id: 'paper', title: 'Deposit Paper', icon: 'filedown' }] : null);
  const canvasRef = useRef<HTMLDivElement>(null);
  const scaleRef = useRef(1);
  const z = useRef(10), session = useRef(0);
  const toastTimer = useRef(0);
  const openedSession = useRef<number | undefined>(undefined);

  const notify = useCallback((text: string, error = false) => {
    setToast({ text, error }); window.clearTimeout(toastTimer.current);
    toastTimer.current = window.setTimeout(() => setToast(null), error ? 6500 : 3600);
  }, []);

  const reloadBoot = useCallback(async () => {
    const reply = await action('newsBoot');
    if (reply.ok) setBoot({ me: reply.me, company: reply.company });
  }, []);

  const newWindow = (id: string, offset = 0): WindowState => {
    const [width, height] = SIZES[id]!;
    return { id, x: bounds((WIDTH - width) / 2 + offset, 4, WIDTH - width - 4), y: bounds(MENU + (HEIGHT - MENU - DOCK - height) / 2 + offset, MENU + 4, HEIGHT - DOCK - height),
      width, height, z: ++z.current, minimized: false, maximized: false };
  };

  const beginSession = useCallback((payload: LaptopData) => {
    session.current++;
    setData(payload); setPanel(null); setMenu(null); setToast(null); setReader(null);
    setVisible(true); setBooting(true);
    // The browser preview can start on another app: ?app=writer
    const first = isPreview && new URLSearchParams(window.location.search).get('app');
    setWindows([newWindow(first && SIZES[first] ? first : 'portal')]);
    void reloadBoot();
    window.setTimeout(() => setBooting(false), 900);
  }, [reloadBoot]);

  useEffect(() => {
    if (isPreview) beginSession(previewData());
    function message(event: MessageEvent) {
      if (event.data?.type === 'open' && event.data.payload?.player) {
        // The game sends the open message more than once to a starting page; only the first counts.
        const id = event.data.payload.session;
        if (id !== undefined && id === openedSession.current) return;
        openedSession.current = id;
        beginSession(event.data.payload);
      }
      if (event.data?.type === 'close') { openedSession.current = undefined; session.current++; setVisible(false); setPanel(null); setMenu(null); }
      if (event.data?.type === 'reader' && event.data.issue?.pages) setReader({ issue: event.data.issue, page: 0 });
      if (event.data?.type === 'radial') setRadial(Array.isArray(event.data.items) ? event.data.items : null);
    }
    window.addEventListener('message', message);
    void nui('ready', { dui: isDui });
    const timer = window.setInterval(() => setClock(new Date()), 1000);
    return () => { window.removeEventListener('message', message); window.clearInterval(timer); };
  }, [beginSession]);

  useEffect(() => {
    if (!visible || !canvasRef.current) return;
    const element = canvasRef.current;
    const resize = () => {
      const scale = element.clientWidth / WIDTH;
      scaleRef.current = scale;
      element.style.setProperty('--desktop-scale', String(scale));
    };
    resize(); const observer = new ResizeObserver(resize); observer.observe(element);
    return () => observer.disconnect();
  }, [visible]);

  async function close() {
    const result = await nui('close');
    if (result.ok) { session.current++; setVisible(false); setPanel(null); setMenu(null); }
    else notify(result.error || 'Unable to close.', true);
  }
  const closeReader = () => { setReader(null); void nui('readerClose'); };

  // Settings, Interface Sounds turns the button sounds off too.
  useEffect(() => { setSoundsEnabled(data.settings.sounds); }, [data.settings.sounds]);

  // A printed copy is read full screen: the page keeps its laid-out size and
  // is zoomed to fill the screen, so the words grow with it.
  useEffect(() => {
    if (!reader) return;
    const fit = () => setReaderZoom(Math.max(1, Math.min((window.innerHeight - 40) / READER_H, (window.innerWidth - 40) / READER_W)));
    fit();
    window.addEventListener('resize', fit);
    return () => window.removeEventListener('resize', fit);
  }, [!!reader]);

  useEffect(() => {
    const keydown = (event: KeyboardEvent) => {
      if (reader && event.key === 'Escape') { event.preventDefault(); closeReader(); return; }
      if (!visible || event.repeat) return;
      if (event.key === 'Escape') {
        event.preventDefault();
        // Dialogs inside an app close themselves first.
        const modal = document.querySelector<HTMLElement>('.mb-overlay, .ns-modal, .cm-viewer');
        if (modal) modal.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
        else if (menu) setMenu(null);
        else if (panel) setPanel(null);
        else void close();
      }
      if ((event.ctrlKey || event.metaKey) && event.key === ' ') {
        event.preventDefault(); setMenu(null); setQuery(''); setPanel(panel === 'spotlight' ? null : 'spotlight');
      }
    };
    window.addEventListener('keydown', keydown);
    return () => window.removeEventListener('keydown', keydown);
  });

  const updateWindow = (id: string, update: Partial<WindowState>) => setWindows(current => current.map(win => win.id === id ? { ...win, ...update } : win));
  const focus = (id: string) => { updateWindow(id, { z: ++z.current, minimized: false }); setPanel(null); };
  const active = windows.filter(win => !win.minimized).sort((a, b) => b.z - a.z)[0]?.id;
  const activeApp = ALL.find(app => app.id === active);

  function openApp(id: string) {
    setPanel(null); setMenu(null);
    if (windows.some(win => win.id === id)) focus(id);
    else setWindows(current => [...current, newWindow(id, Math.min(current.length * 18, 54))]);
  }
  const closeWindow = (id: string) => setWindows(current => current.filter(win => win.id !== id));

  async function updateSettings(settings: Settings) {
    if (settingsBusy) return;
    const generation = session.current;
    setSettingsBusy(true);
    const result = await action('settings', { ...settings });
    if (generation !== session.current) return;
    setSettingsBusy(false);
    if (!result.ok || !result.settings) { notify(result.error || 'Could not save settings.', true); return; }
    setData(current => ({ ...current, settings: result.settings! }));
  }

  function drag(event: ReactPointerEvent, win: WindowState, resizing = false) {
    if (event.button !== 0 || win.maximized || (!resizing && (event.target as HTMLElement).closest('button'))) return;
    event.preventDefault();
    const target = event.currentTarget as HTMLElement;
    target.setPointerCapture(event.pointerId);
    const startX = event.clientX, startY = event.clientY;
    const [, , minW, minH] = SIZES[win.id]!;
    const onMove = (move: PointerEvent) => {
      const dx = (move.clientX - startX) / scaleRef.current, dy = (move.clientY - startY) / scaleRef.current;
      if (resizing) updateWindow(win.id, { width: bounds(win.width + dx, minW, WIDTH - win.x - 4), height: bounds(win.height + dy, minH, HEIGHT - win.y - 4) });
      else updateWindow(win.id, { x: bounds(win.x + dx, 80 - win.width, WIDTH - 80), y: bounds(win.y + dy, MENU, HEIGHT - 50) });
    };
    const end = () => {
      target.removeEventListener('pointermove', onMove);
      target.removeEventListener('pointerup', end);
      target.removeEventListener('pointercancel', end);
      target.removeEventListener('lostpointercapture', end);
    };
    target.addEventListener('pointermove', onMove);
    target.addEventListener('pointerup', end);
    target.addEventListener('pointercancel', end);
    target.addEventListener('lostpointercapture', end);
  }

  const showDesktop = () => { const allMinimized = windows.every(win => win.minimized); setWindows(current => current.map(win => ({ ...win, minimized: !allMinimized }))); };
  // Edit commands act on the focused field; the menus never take focus from it.
  const edit = (command: string) => () => { document.execCommand(command); };
  const menus: Record<string, MenuItem[]> = {
    nova: [
      { label: `About This ${data.deviceName}`, run: () => notify(`${data.deviceName} · Weazel News edition · ${data.serverName}`) },
      { label: 'Spotlight Search', keys: 'Ctrl Space', run: () => { setQuery(''); setPanel('spotlight'); } },
      // Only on the laptop prop: move the screen with the gizmo.
      ...(isDui ? [{ label: 'Adjust Screen Position…', run: () => void nui('adjustScreen') }] : []), null,
      { label: 'Shut Down…', run: () => void close() }
    ],
    File: [
      { label: 'New Article', run: () => openApp('writer') },
      { label: 'Open Newsstand', run: () => openApp('newsstand') }, null,
      { label: 'Close Window', disabled: !active, run: () => active && closeWindow(active) }
    ],
    Edit: [
      { label: 'Undo', keys: 'Ctrl Z', run: edit('undo') }, { label: 'Redo', keys: 'Ctrl Y', run: edit('redo') }, null,
      { label: 'Select All', keys: 'Ctrl A', run: edit('selectAll') }
    ],
    View: [
      { label: windows.length && windows.every(win => win.minimized) ? 'Restore Windows' : 'Show Desktop', disabled: !windows.length, run: showDesktop },
      { label: 'Enter Full Screen', disabled: !active, run: () => active && updateWindow(active, { maximized: true }) }
    ],
    Settings: [
      { label: 'Light Appearance', checked: data.settings.theme === 'light', disabled: settingsBusy, run: () => void updateSettings({ ...data.settings, theme: 'light' }) },
      { label: 'Dark Appearance', checked: data.settings.theme === 'dark', disabled: settingsBusy, run: () => void updateSettings({ ...data.settings, theme: 'dark' }) }, null,
      ...(['bloom', 'dusk', 'aurora'] as const).map(wallpaper => ({ label: `${wallpaper === 'bloom' ? 'Blue Hour' : wallpaper === 'dusk' ? 'Afterglow' : 'Northern Lights'} Wallpaper`,
        checked: data.settings.wallpaper === wallpaper, disabled: settingsBusy, run: () => void updateSettings({ ...data.settings, wallpaper }) })), null,
      { label: 'Interface Sounds', checked: data.settings.sounds, disabled: settingsBusy, run: () => void updateSettings({ ...data.settings, sounds: !data.settings.sounds }) }
    ],
    Window: [
      { label: 'Minimize', disabled: !active, run: () => active && updateWindow(active, { minimized: true }) },
      { label: 'Zoom', disabled: !active, run: () => { const win = windows.find(w => w.id === active); if (win) updateWindow(win.id, { maximized: !win.maximized }); } }, null,
      ...windows.map(win => ({ label: ALL.find(app => app.id === win.id)!.name, checked: active === win.id, run: () => focus(win.id) })),
      ...(windows.length ? [] : [{ label: 'No open windows', disabled: true, run: () => undefined }])
    ],
    Help: [
      { label: 'Writing a story', run: () => notify('Write it in Weazel Writer and submit it. An editor approves it, then it can go in the magazine.') },
      { label: 'Publishing an issue', run: () => notify('Drag approved stories onto pages in the Magazine Editor, then press Publish. Print copies from the Newsstand.') }
    ]
  };

  const needle = query.trim().toLowerCase();
  const found = ALL.filter(app => `${app.name} ${app.title}`.toLowerCase().includes(needle));
  const { me, company } = boot;

  if (radial) return <Radial items={radial} onSelect={id => { setRadial(null); void nui('radialSelect', { id }); }} onClose={() => { setRadial(null); void nui('radialClose'); }} />;

  if (reader) return <div className="reader-stage">
    <div className="reader-zoom" style={{ zoom: readerZoom }}>
      <IssueReader issue={reader.issue} page={reader.page} setPage={page => setReader({ ...reader, page })} />
    </div>
    <button className="reader-close" onClick={closeReader}><Icon name="close" size={16} />Close magazine <kbd>ESC</kbd></button>
  </div>;

  if (!visible) {
    // On the laptop prop a closed laptop is a dark screen, not a see-through one.
    // On a laptop nobody is using: the lock screen.
    if (isDui) return <div className="dui-screen lock-screen" data-wallpaper={data.settings.wallpaper}>
      <div className="wallpaper" />
      <div className="lock-clock"><span>{clock.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}</span>
        <strong>{clock.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' }).replace(/s?[AP]M/, '')}</strong></div>
      <div className="lock-user"><NovaMark /><b>Weazel News</b><small>{data.deviceName}</small></div>
    </div>;
    if (!isPreview) return null;
    return <div className="preview-closed"><NovaMark /><h1>See you around.</h1><p>Your laptop is closed.</p><button className="primary" onClick={() => beginSession(previewData())}><Icon name="power" /> Open laptop</button></div>;
  }

  const screen = <main className="desktop" onContextMenu={event => event.preventDefault()} style={{ width: WIDTH, height: HEIGHT }}
    onPointerDownCapture={event => { if (menu && !(event.target as HTMLElement).closest('.menubar-menus, .menu-dropdown')) setMenu(null); }}>
    <div className="wallpaper" onPointerDown={() => setPanel(null)} />

    <header className="menubar">
      <nav className="menubar-menus" onMouseDown={event => event.preventDefault()}>
        {Object.keys(menus).map(name => <div className="menubar-item" key={name}>
          <button className={`${menu === name ? 'open' : ''} ${name === 'nova' ? 'menubar-logo' : ''}`} aria-label={name === 'nova' ? 'System menu' : name}
            onClick={() => { setPanel(null); setMenu(menu === name ? null : name); }} onMouseEnter={() => { if (menu && menu !== name) setMenu(name); }}>
            {name === 'nova' ? <NovaMark /> : name}
          </button>
          {name === 'nova' && activeApp && <strong className="menubar-app">{activeApp.name}</strong>}
          {menu === name && <div className="menu-dropdown" role="menu">
            {menus[name]!.map((item, i) => item ? <button key={item.label} role="menuitem" disabled={item.disabled} onClick={() => { setMenu(null); item.run(); }}>
              <span className="menu-check">{item.checked && <Icon name="check" size={12} stroke={2.4} />}</span>{item.label}{item.keys && <kbd>{item.keys}</kbd>}
            </button> : <hr key={`sep-${i}`} />)}
          </div>}
        </div>)}
      </nav>
      <div className="menubar-status">
        <button aria-label="Spotlight search" className={panel === 'spotlight' ? 'open' : ''} onClick={() => { setMenu(null); setQuery(''); setPanel(panel === 'spotlight' ? null : 'spotlight'); }}><Icon name="search" size={14} stroke={2} /></button>
        <button aria-label="Control center" className={`menubar-tray ${panel === 'quick' ? 'open' : ''}`} onClick={() => { setMenu(null); setPanel(panel === 'quick' ? null : 'quick'); }}>
          <Icon name="wifi" size={15} stroke={2} /><Icon name="battery" size={17} stroke={1.8} /><Icon name={data.settings.sounds ? 'volume' : 'muted'} size={15} stroke={2} />
        </button>
        <button className={`menubar-clock ${panel === 'calendar' ? 'open' : ''}`} title={clock.toLocaleString()} onClick={() => { setMenu(null); setPanel(panel === 'calendar' ? null : 'calendar'); }}>
          {clock.toLocaleDateString('en-US', { weekday: 'short' })} {clock.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}
        </button>
      </div>
    </header>

    {windows.map(win => {
      const app = ALL.find(item => item.id === win.id)!;
      return <section key={win.id} className={`app-window ${active === win.id ? 'focused' : ''} ${win.maximized ? 'maximized' : ''}`}
        data-app={win.id} aria-label={`${app.name} window`} hidden={win.minimized}
        onPointerDown={() => focus(win.id)} style={{ left: win.maximized ? 0 : win.x, top: win.maximized ? MENU : win.y,
          width: win.maximized ? WIDTH : win.width, height: win.maximized ? HEIGHT - MENU - DOCK : win.height, zIndex: win.z }}>
        <header className="window-titlebar" onPointerDown={event => drag(event, win)} onDoubleClick={event => {
          if (!(event.target as HTMLElement).closest('button')) updateWindow(win.id, { maximized: !win.maximized });
        }}>
          <div className="traffic-lights">
            <button className="light light-close" aria-label={`Close ${app.name}`} onClick={() => closeWindow(win.id)}><Icon name="close" size={8} stroke={3} /></button>
            <button className="light light-minimize" aria-label={`Minimize ${app.name}`} onClick={() => updateWindow(win.id, { minimized: true })}><Icon name="minimize" size={8} stroke={3} /></button>
            <button className="light light-zoom" aria-label={`${win.maximized ? 'Restore' : 'Maximize'} ${app.name}`} onClick={() => updateWindow(win.id, { maximized: !win.maximized })}><Icon name="plus" size={8} stroke={3} /></button>
          </div>
          <div className="window-title">{app.title}</div>
        </header>
        <div className="window-content">
          {win.id === 'portal' && <Portal me={me} company={company} reloadBoot={reloadBoot} notify={notify} logOut={() => closeWindow('portal')} />}
          {win.id === 'writer' && <Writer me={me} notify={notify} />}
          {win.id === 'magazine' && <MagazineEditor me={me} notify={notify} />}
          {win.id === 'newsstand' && <Newsstand me={me} notify={notify} />}
          {win.id === 'camera' && <CameraApp me={me} notify={notify} />}
          {win.id === 'trash' && <Trash me={me} notify={notify} />}
        </div>
        {!win.maximized && <div className="resize-grip" onPointerDown={event => drag(event, win, true)} />}
      </section>;
    })}

    {panel === 'spotlight' && <section className="spotlight glass" aria-label="Spotlight search">
      <label><Icon name="search" size={22} /><input autoFocus value={query} onChange={event => setQuery(event.target.value)} placeholder="Spotlight Search" aria-label="Search apps"
        onKeyDown={event => { if (event.key === 'Enter' && found[0]) openApp(found[0].id); }} /></label>
      <div className="spotlight-results">
        {found.length > 0 && <small>{needle ? 'Applications' : 'Suggested'}</small>}
        {found.map(app => <button key={app.id} onClick={() => openApp(app.id)}><span className={`spot-icon ${app.id === 'trash' ? 'grey' : ''}`}><Icon name={app.icon} size={15} stroke={2} /></span><span>{app.name}</span><em>{app.title}</em></button>)}
        {!found.length && <p className="empty-search">No results for “{query.trim()}”.</p>}
      </div>
    </section>}

    {panel === 'quick' && <section className="quick-panel glass" aria-label="Control center">
      <div className="panel-heading"><strong>Control Center</strong></div>
      <div className="connection-card"><span><Icon name="wifi" size={22} /></span><div><strong>{isPreview ? 'Browser preview' : data.serverName}</strong><small>{isPreview ? 'Local demo session' : 'Connected to game server'}</small></div><i className="status-dot" /></div>
      <div className="quick-tiles"><button disabled={settingsBusy} className={data.settings.sounds ? 'selected' : ''} onClick={() => void updateSettings({ ...data.settings, sounds: !data.settings.sounds })}><Icon name={data.settings.sounds ? 'volume' : 'muted'} size={22} />Interface sounds<span>{data.settings.sounds ? 'On' : 'Off'}</span></button>
        <button disabled={settingsBusy} className={data.settings.theme === 'dark' ? 'selected' : ''} onClick={() => void updateSettings({ ...data.settings, theme: data.settings.theme === 'dark' ? 'light' : 'dark' })}><Icon name="moon" size={22} />Dark mode<span>{data.settings.theme === 'dark' ? 'On' : 'Off'}</span></button></div>
      <div className="quick-footer"><Icon name="monitor" size={16} /><span>{data.deviceName}</span><span>{me.staff ? (me.onDuty ? 'On duty' : 'Off duty') : 'Guest'}</span></div>
    </section>}
    {panel === 'calendar' && <Calendar clock={clock} />}

    <nav className="dock" aria-label="Dock">
      {APPS.map(app => {
        const win = windows.find(w => w.id === app.id);
        return <button key={app.id} aria-label={app.name} className={`dock-item ${win ? 'running' : ''}`} onClick={() => openApp(app.id)}>
          <span className="dock-tip">{app.name}</span>
          <span className="dock-icon"><Icon name={app.icon} size={27} stroke={2.2} /></span>
        </button>;
      })}
      <span className="dock-divider" />
      <button className={`dock-item ${windows.some(w => w.id === 'trash') ? 'running' : ''}`} aria-label="Trash" onClick={() => openApp('trash')}>
        <span className="dock-tip">Trash</span>
        <span className="dock-icon dock-system"><Icon name="trash" size={26} stroke={1.8} /></span>
      </button>
    </nav>

    {toast && <div className={`toast glass ${toast.error ? 'error' : ''}`} role="status"><span className="toast-icon"><Icon name={toast.error ? 'info' : 'bell'} size={18} /></span><div><strong>{toast.error ? 'Something needs attention' : 'Weazel News'}</strong><p>{toast.text}</p></div><button aria-label="Dismiss notification" onClick={() => setToast(null)}><Icon name="close" size={14} /></button></div>}
    {booting && <div className="boot-screen"><NovaMark /><i><b /></i></div>}
  </main>;

  const look = { 'data-theme': data.settings.theme, 'data-wallpaper': data.settings.wallpaper, 'data-accent': data.settings.accent };
  // On the prop the page is exactly the screen; in the overlay it sits in a drawn laptop.
  if (isDui) return <div className="dui-screen" ref={canvasRef} {...look}>{screen}</div>;
  return <div className={`laptop-stage ${isPreview ? 'preview' : ''}`}>
    <div className="laptop-device" {...look}>
      <div className="camera-bezel"><span /><i /></div>
      <div className="laptop-screen" ref={canvasRef}>{screen}</div>
      <div className="bottom-bezel"><span>{data.deviceName}</span></div>
      <div className="laptop-base"><i /></div>
    </div>
    <span className="escape-hint"><kbd>ESC</kbd> close laptop<span /><kbd>Ctrl</kbd> + <kbd>Space</kbd> Spotlight<span />Double-click a title bar to zoom</span>
  </div>;
}

function Calendar({ clock }: { clock: Date }) {
  const [month, setMonth] = useState(new Date(clock.getFullYear(), clock.getMonth(), 1));
  const leading = (month.getDay() + 6) % 7;
  const days = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
  return <section className="calendar-panel glass" aria-label="Calendar">
    <div className="calendar-date">{clock.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' })}</div>
    <div className="calendar-toolbar"><strong>{month.toLocaleDateString('en-GB', { month: 'long', year: 'numeric' })}</strong><button aria-label="Previous month" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))}><Icon name="left" /></button><button aria-label="Next month" onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))}><Icon name="right" /></button></div>
    <div className="calendar-grid">{['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day, i) => <small key={`day-${i}`}>{day}</small>)}{Array.from({ length: leading }, (_, i) => <span key={`empty-${i}`} />)}{Array.from({ length: days }, (_, i) => <span key={i} className={clock.getDate() === i + 1 && clock.getMonth() === month.getMonth() && clock.getFullYear() === month.getFullYear() ? 'today' : ''}>{i + 1}</span>)}</div>
    <button className="soft-button calendar-today" onClick={() => setMonth(new Date(clock.getFullYear(), clock.getMonth(), 1))}>Back to today</button>
  </section>;
}
