import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { useSelector } from 'react-redux';
import './Phone.css';

import { getWallpaper, DESIGN_HEIGHT } from '../../config/phone.config';

import StatusBar from '../StatusBar/StatusBar';
import HomeBar from '../HomeBar/HomeBar';
import LockScreen from '../../screens/LockScreen/LockScreen';
import HomeScreen from '../../screens/HomeScreen/HomeScreen';
import NpHome from '../../np/NpHome';
import ControlLegend from '../../np/ControlLegend';
import NpNotifications from '../../np/NpNotifications';
import PhoneSetup from '../../np/PhoneSetup';
import { isBank } from '../../np/banks';
import '../../np/apps/restyle.css';
import AppScreen from '../../screens/AppScreen/AppScreen';
import CallOverlay from '../../app/phone/call/CallOverlay';
import NotificationBanner from '../Notifications/NotificationBanner';
import StatusToast from '../Notifications/StatusToast';
import AirdropIsland from '../Airdrop/AirdropIsland';
import AirdropPicker from '../Airdrop/AirdropPicker';
import TimerIsland from '../Clock/TimerIsland';
import AlarmRing from '../Clock/AlarmRing';
import AlertDialog from '../AlertDialog/AlertDialog';
import InputDialog from '../InputDialog/InputDialog';
import ControlCenter from '../ControlCenter/ControlCenter';
import NowPlayingIsland from '../NowPlaying/NowPlayingIsland';
import DuoHome from '../../duo/DuoHome';
import DuoHardware from '../../duo/DuoHardware';
import { isDuo, usesIosApps, finishOf } from '../../duo/skin';

export default function Phone() {
    const locked = useSelector((s) => s.phone.locked);
    const activeApp = useSelector((s) => s.phone.activeApp);
    const wallpaperKey = useSelector((s) => s.settings.wallpaper);
    const brightness = useSelector((s) => s.settings.brightness);
    const scale = useSelector((s) => s.settings.scale);
    const inCall = useSelector((s) => !!s.call.state);
    const folded = useSelector((s) => s.phone.folded);
    const closing = useSelector((s) => s.phone.phase === 'closing');
    const homeStyle = useSelector((s) => s.phone.ui.homeStyle);
    const finish = useSelector((s) => s.phone.ui.finish);
    const duo = isDuo(homeStyle);
    // Phone Setup only themes the NoPixel Bank app, which the iPhone skins don't use.
    const needsSetup = useSelector(
        (s) =>
            s.phone.ui.phoneSetup !== false &&
            !usesIosApps(s.phone.ui.homeStyle) &&
            s.settings.loaded &&
            !isBank(s.settings.bank),
    );

    const dim = Math.max(0, Math.min(0.72, ((100 - brightness) / 100) * 0.9));

    const screenRef = useRef(null);

    const [lockMounted, setLockMounted] = useState(locked);
    const [lockExiting, setLockExiting] = useState(false);

    useEffect(() => {
        if (locked) {
            setLockMounted(true);
            setLockExiting(false);
        } else if (lockMounted) {
            setLockExiting(true);
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [locked]);

    const handleLockExited = () => {
        setLockMounted(false);
        setLockExiting(false);
    };

    // 1em inside the screen = 1/52.75 of its height (an 844pt-tall design). Height-based so
    // unfolding (which only widens the screen) never rescales text or icons.
    useLayoutEffect(() => {
        const el = screenRef.current;
        if (!el) return;
        let raf = 0;
        const applyScale = () => {
            const next = `${(el.clientHeight / DESIGN_HEIGHT) * 16}px`;
            if (el.style.fontSize !== next) el.style.fontSize = next;
        };
        applyScale();
        const ro = new ResizeObserver(() => {
            cancelAnimationFrame(raf);
            raf = requestAnimationFrame(applyScale);
        });
        ro.observe(el);
        return () => {
            cancelAnimationFrame(raf);
            ro.disconnect();
        };
    }, []);

    const showHomeBar = !locked && !inCall;

    return (
        <div
            className={`phone ${folded ? 'is-folded' : 'is-unfolded'}${closing ? ' is-closing' : ''}${
                duo ? ` duo-skin duo-finish--${finishOf(finish)}` : homeStyle === 'ios' ? '' : ' np-skin'
            }`}
            style={{ '--phone-scale': (scale || 100) / 100 }}
        >
            {duo && <DuoHardware />}
            <div className="phone__frame" />
            <div className="phone__screen" ref={screenRef}>
                <img className="phone__wallpaper" src={getWallpaper(wallpaperKey)} alt="" />

                {!locked && (
                    <div className="phone__layer phone__layer--base">
                        {activeApp ? (
                            <AppScreen appId={activeApp} />
                        ) : duo ? (
                            <DuoHome />
                        ) : homeStyle === 'ios' ? (
                            <HomeScreen />
                        ) : (
                            <NpHome />
                        )}
                    </div>
                )}

                {lockMounted && <LockScreen exiting={lockExiting} onExited={handleLockExited} />}

                {!locked && needsSetup && <PhoneSetup />}

                <StatusBar />
                {showHomeBar && <HomeBar />}

                <ControlCenter />

                {!locked && <NpNotifications />}

                {!locked && !inCall && <NotificationBanner />}

                {!locked && <StatusToast />}

                {!inCall && <AirdropIsland />}

                <TimerIsland />
                <AlarmRing />

                {!inCall && <NowPlayingIsland />}

                <CallOverlay />

                <AlertDialog />

                <InputDialog />

                <AirdropPicker />

                {dim > 0 && <div className="phone__dim" style={{ opacity: dim }} />}
            </div>

            <ControlLegend />
        </div>
    );
}