// NoPixel Settings. Every option persists through the existing phone:saveSettings / profile
// callbacks (per-character settings JSON in oph3z_phone_players).
import { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
    faUser,
    faTableCells,
    faShareNodes,
    faMobileScreen,
    faEyeSlash,
    faImage,
    faSliders,
    faCopy,
    faChevronRight,
    faMusic,
    faLanguage,
    faPlane,
    faBell,
    faBuildingColumns,
    faHandPointer,
} from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { saveSetting, saveSettingLive, setAirplane } from '../../../store/slices/settingsSlice';
import { saveProfileName } from '../../../store/slices/phoneSlice';
import { openShare } from '../../../store/slices/airdropSlice';
import { loadRingtones } from '../../../store/slices/ringtonesSlice';
import { pushToast } from '../../../store/slices/toastSlice';
import { copyText } from '../../../utils/clipboard';
import { WALLPAPER_PRESETS, isWallpaperUrl, getWallpaper } from '../../../config/phone.config';
import { useAvailableApps } from '../../../app/useAvailableApps';
import { NpAppIcon } from '../../npIcons';
import { BANKS, getBank } from '../../banks';
import { NpApp, Panel, BigHeader, Body, Toggle, Sheet, Field, Btn, Msg } from '../../ui/kit';
import './settings.css';

function Row({ icon, iconNode, title, sub, onClick, end, chevron = true }) {
    const Tag = onClick ? 'button' : 'div';
    return (
        <Tag className="nps-row" onClick={onClick}>
            <span className="nps-row__ico">{iconNode || <FaIcon icon={icon} />}</span>
            <span className="nps-row__main">
                <span className="nps-row__title">{title}</span>
                {sub && <span className="nps-row__sub">{sub}</span>}
            </span>
            {end}
            {onClick && chevron && !end && <FaIcon icon={faChevronRight} className="nps-row__chev" />}
        </Tag>
    );
}

const wallpaperName = (key) => {
    if (isWallpaperUrl(key)) return 'Custom';
    const p = WALLPAPER_PRESETS.find((w) => w.key === key);
    if (key === 'noPixel') return 'Graphite';
    return p ? p.name : 'Ember';
};

export default function NpSettings() {
    const dispatch = useDispatch();
    const identity = useSelector((s) => s.phone.identity);
    const settings = useSelector((s) => s.settings);
    const ui = useSelector((s) => s.phone.ui);
    const { list } = useAvailableApps();
    const [sheet, setSheet] = useState(null);

    const notifOn = (id) => !(settings.notifApps && settings.notifApps[id] === false);
    const setNotif = (id, v) => dispatch(saveSetting('notifApps', { ...(settings.notifApps || {}), [id]: v }));

    const appRows = list
        .filter((a) => a.id !== 'contacts' && a.id !== 'appstore' && a.id !== 'camera')
        .sort((a, b) => a.label.localeCompare(b.label));

    return (
        <NpApp theme="dark" className="nps">
            <Panel>
                <BigHeader title="Settings" sub="Manage your phone settings" />
                <Body>
                    <div className="nps-group">About</div>
                    <div className="nps-card">
                        <Row icon={faUser} title={identity.name || 'Unnamed'} sub="Phone Account" onClick={() => setSheet('name')} />
                        <Row
                            icon={faTableCells}
                            title={identity.number || '—'}
                            sub="Phone Number"
                            onClick={() => {
                                copyText(identity.number || '');
                                dispatch(pushToast({ title: 'Settings', body: 'Number copied.' }));
                            }}
                            end={<FaIcon icon={faCopy} className="nps-row__chev" />}
                        />
                        <Row
                            icon={faShareNodes}
                            title="Share My Contact"
                            sub="Send your number to someone nearby"
                            onClick={() =>
                                dispatch(
                                    openShare({
                                        kind: 'contact',
                                        contact: { name: identity.name, number: identity.number, img: identity.avatar },
                                    }),
                                )
                            }
                        />
                    </div>

                    <div className="nps-group">Privacy</div>
                    <div className="nps-card">
                        <Row icon={faMobileScreen} title={identity.name || 'This phone'} sub="Device Name · Shown to nearby phones" onClick={() => setSheet('name')} />
                        <Row
                            icon={faEyeSlash}
                            title="Hide From Nearby Devices"
                            sub="Keep this phone out of nearby device lists"
                            end={<Toggle on={!settings.sharedrop} onChange={(v) => dispatch(saveSetting('sharedrop', !v))} />}
                        />
                        <Row
                            icon={faPlane}
                            title="Airplane Mode"
                            sub="Unreachable for calls and messages"
                            end={<Toggle on={!!settings.airplane} onChange={(v) => dispatch(setAirplane(v))} />}
                        />
                    </div>

                    <div className="nps-group">Appearance</div>
                    <div className="nps-card">
                        <Row icon={faImage} title={wallpaperName(settings.wallpaper)} sub="Cover Image · Wallpaper Style" onClick={() => setSheet('wallpaper')} />
                        <Row icon={faSliders} title="Interface" sub="Control Hints · Brightness · Size" onClick={() => setSheet('interface')} />
                        <Row icon={faLanguage} title="Language" sub={(settings.language || 'en').toUpperCase()} onClick={() => setSheet('language')} />
                        <Row icon={faBuildingColumns} title={getBank(settings.bank).lines.join(' ')} sub="Bank Provider · Bank app style" onClick={() => setSheet('bank')} />
                    </div>

                    <div className="nps-group">Sounds</div>
                    <div className="nps-card">
                        <Row icon={faMusic} title="Ringtone" sub="Incoming call sound" onClick={() => setSheet('ringtone')} />
                        <Row
                            icon={faBell}
                            title="Notification Sound"
                            sub="Play a sound for new notifications"
                            end={<Toggle on={settings.notifSound !== false} onChange={(v) => dispatch(saveSetting('notifSound', v))} />}
                        />
                        {ui.sounds && (
                            <Row
                                icon={faHandPointer}
                                title="Interface Sounds"
                                sub="Hover, click and select sounds"
                                end={<Toggle on={settings.uiSounds !== false} onChange={(v) => dispatch(saveSetting('uiSounds', v))} />}
                            />
                        )}
                    </div>

                    <div className="nps-group">Apps</div>
                    <div className="nps-card">
                        {appRows.map((a) => (
                            <Row
                                key={a.id}
                                iconNode={
                                    <span className="nps-appico">
                                        <NpAppIcon id={a.id} label={a.label} iconUrl={a.external ? a.icon : null} />
                                    </span>
                                }
                                title={a.label}
                                sub="Notifications"
                                end={<Toggle on={notifOn(a.id)} onChange={(v) => setNotif(a.id, v)} />}
                            />
                        ))}
                    </div>
                </Body>
            </Panel>

            {sheet === 'name' && <NameSheet initial={identity.name} onClose={() => setSheet(null)} />}
            {sheet === 'wallpaper' && <WallpaperSheet current={settings.wallpaper} onClose={() => setSheet(null)} />}
            {sheet === 'interface' && <InterfaceSheet settings={settings} ui={ui} onClose={() => setSheet(null)} />}
            {sheet === 'language' && <LanguageSheet current={settings.language} onClose={() => setSheet(null)} />}
            {sheet === 'ringtone' && <RingtoneSheet current={settings.ringtone} onClose={() => setSheet(null)} />}
            {sheet === 'bank' && <BankSheet current={getBank(settings.bank).id} onClose={() => setSheet(null)} />}
        </NpApp>
    );
}

function NameSheet({ initial, onClose }) {
    const dispatch = useDispatch();
    const [name, setName] = useState(initial || '');
    return (
        <Sheet title="Phone Account" sub="Shown to nearby phones and on calls" onClose={onClose}>
            <Field label="Name" value={name} max={40} onChange={setName} autoFocus onEnter={() => name.trim() && (dispatch(saveProfileName(name)), onClose())} />
            <Btn className="npk-btn--block" disabled={!name.trim()} onClick={() => (dispatch(saveProfileName(name)), onClose())}>
                Save
            </Btn>
        </Sheet>
    );
}

function WallpaperSheet({ current, onClose }) {
    const dispatch = useDispatch();
    const [url, setUrl] = useState(isWallpaperUrl(current) ? current : '');
    const presets = WALLPAPER_PRESETS.filter((w) => w.key !== 'noPixel');
    const pick = (key) => dispatch(saveSetting('wallpaper', key));
    return (
        <Sheet title="Wallpaper" onClose={onClose}>
            <div className="nps-walls">
                {presets.map((w) => (
                    <button
                        key={w.key}
                        className={`nps-wall${current === w.key || (current === 'noPixel' && w.key === 'graphite') ? ' is-on' : ''}`}
                        onClick={() => pick(w.key)}
                    >
                        <img src={getWallpaper(w.key)} alt="" />
                        <span>{w.name}</span>
                    </button>
                ))}
            </div>
            <Field label="Custom image URL" value={url} max={512} placeholder="https://…" onChange={setUrl} />
            <Btn className="npk-btn--block" disabled={!/^https?:\/\//i.test(url.trim())} onClick={() => pick(url.trim())}>
                Use custom image
            </Btn>
        </Sheet>
    );
}

function Slider({ label, value, min, max, onChange, suffix = '%' }) {
    return (
        <label className="nps-slider">
            <span>
                {label}
                <b>
                    {Math.round(value)}
                    {suffix}
                </b>
            </span>
            <input type="range" min={min} max={max} value={value} onChange={(e) => onChange(Number(e.target.value))} />
        </label>
    );
}

function InterfaceSheet({ settings, ui, onClose }) {
    const dispatch = useDispatch();
    return (
        <Sheet title="Interface" onClose={onClose}>
            {ui.legend && (
                <div className="nps-line">
                    <span>
                        <b>Control hints</b>
                        <em>Key prompts beside the phone</em>
                    </span>
                    <Toggle on={settings.hints !== false} onChange={(v) => dispatch(saveSetting('hints', v))} />
                </div>
            )}
            <Slider label="Brightness" value={settings.brightness ?? 100} min={20} max={100} onChange={(v) => dispatch(saveSettingLive('brightness', v))} />
            <Slider label="Phone size" value={settings.scale ?? 100} min={75} max={100} onChange={(v) => dispatch(saveSettingLive('scale', v))} />
        </Sheet>
    );
}

function LanguageSheet({ current, onClose }) {
    const dispatch = useDispatch();
    const languages = useSelector((s) => s.i18n.languages);
    const list = languages && languages.length ? languages : [{ code: 'en', label: 'English' }];
    return (
        <Sheet title="Language" onClose={onClose}>
            <div className="npk-list">
                {list.map((l) => {
                    const code = l.code || l.id || l;
                    return (
                        <button key={code} className={`npk-row nps-pick${current === code ? ' is-on' : ''}`} onClick={() => dispatch(saveSetting('language', code))}>
                            <span className="npk-row__main npk-row__title">{l.label || l.name || code}</span>
                            <span className="nps-dot" />
                        </button>
                    );
                })}
            </div>
        </Sheet>
    );
}

function BankSheet({ current, onClose }) {
    const dispatch = useDispatch();
    return (
        <Sheet title="Bank Provider" sub="Changes the look of the Bank app" onClose={onClose}>
            <div className="npk-list">
                {BANKS.map((b) => (
                    <button key={b.id} className={`npk-row nps-pick${current === b.id ? ' is-on' : ''}`} onClick={() => dispatch(saveSetting('bank', b.id))}>
                        <span className="nps-swatch" style={{ background: b.colors.base }} />
                        <span className="npk-row__main npk-row__title">{b.lines.join(' ')}</span>
                        <span className="nps-dot" />
                    </button>
                ))}
            </div>
        </Sheet>
    );
}

function RingtoneSheet({ current, onClose }) {
    const dispatch = useDispatch();
    const items = useSelector((s) => s.ringtones.items);
    const [err, setErr] = useState('');
    useEffect(() => {
        dispatch(loadRingtones());
    }, [dispatch]);
    const selected = current || '';
    return (
        <Sheet title="Ringtone" onClose={onClose}>
            <div className="npk-list">
                {items.map((r) => (
                    <button
                        key={r.id}
                        className={`npk-row nps-pick${(r.url || '') === selected ? ' is-on' : ''}`}
                        onClick={() => {
                            setErr('');
                            dispatch(saveSetting('ringtone', r.url || ''));
                        }}
                    >
                        <span className="npk-row__main npk-row__title">{r.name}</span>
                        <span className="nps-dot" />
                    </button>
                ))}
                {items.length === 0 && <div className="npk-hint">No ringtones available.</div>}
            </div>
            <Msg>{err}</Msg>
        </Sheet>
    );
}
