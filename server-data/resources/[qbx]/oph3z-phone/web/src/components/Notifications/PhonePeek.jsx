import { useLayoutEffect, useRef } from 'react';
import { useSelector } from 'react-redux';

import { getWallpaper, DESIGN_HEIGHT } from '../../config/phone.config';
import StatusBar from '../StatusBar/StatusBar';
import NotificationCard from './NotificationCard';
import DuoHardware from '../../duo/DuoHardware';
import { isDuo, finishOf } from '../../duo/skin';

export default function PhonePeek({ notif, onDone }) {
    const wallpaperKey = useSelector((s) => s.settings.wallpaper);
    const scale = useSelector((s) => s.settings.scale);
    const duo = useSelector((s) => isDuo(s.phone.ui.homeStyle));
    const finish = useSelector((s) => s.phone.ui.finish);
    const screenRef = useRef(null);

    useLayoutEffect(() => {
        const el = screenRef.current;
        if (!el) return undefined;
        const apply = () => {
            el.style.fontSize = `${(el.clientHeight / DESIGN_HEIGHT) * 16}px`;
        };
        apply();
        const ro = new ResizeObserver(apply);
        ro.observe(el);
        return () => ro.disconnect();
    }, []);

    return (
        <div
            className={`phone is-folded phone-peek${duo ? ` duo-skin duo-finish--${finishOf(finish)}` : ''}`}
            style={{ '--phone-scale': (scale || 100) / 100 }}
            onAnimationEnd={(e) => {
                if (e.animationName === 'phone-peek-slide' && onDone) onDone();
            }}
        >
            {duo && <DuoHardware />}
            <div className="phone__frame" />
            <div className="phone__screen phone-peek__screen" ref={screenRef}>
                <img className="phone__wallpaper" src={getWallpaper(wallpaperKey)} alt="" />
                <StatusBar />
                <div className="phone-peek__notif">
                    <NotificationCard notif={notif} />
                </div>
            </div>
        </div>
    );
}