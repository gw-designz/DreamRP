import { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import './NowPlaying.css';
import { fetchNui } from '../../utils/fetchNui';
import { openApp, unlock } from '../../store/slices/phoneSlice';
import { fmtTime, gradientFor } from './util';
import { PlayIcon, PauseIcon, NextIcon, PrevIcon, NoteIcon, Waveform } from './icons';

const command = (action, value) => fetchNui('phone:media:command', { action, value }, {});

export default function NowPlayingIsland() {
    const dispatch = useDispatch();
    const music = useSelector((s) => s.music);
    const activeApp = useSelector((s) => s.phone.activeApp);
    const locked = useSelector((s) => s.phone.locked);
    const inCall = useSelector((s) => !!s.call.state);
    const [expanded, setExpanded] = useState(false);

    const hidden =
        !music.title ||
        (music.appId && activeApp === music.appId) ||
        locked ||
        inCall ||
        (!music.playing && !expanded);
    useEffect(() => {
        if (hidden) setExpanded(false);
    }, [hidden]);
    if (hidden) return null;

    const openOwner = () => {
        if (!music.appId) return;
        dispatch(unlock());
        dispatch(openApp(music.appId));
    };
    const toggle = (e) => {
        e.stopPropagation();
        command('toggle');
    };
    const next = (e) => {
        e.stopPropagation();
        command('next');
    };
    const prev = (e) => {
        e.stopPropagation();
        command('prev');
    };
    const pct = music.duration ? Math.min(100, (music.position / music.duration) * 100) : 0;

    const Art = ({ size }) => (
        <span
            className="np-isl__art"
            style={{
                width: size,
                height: size,
                ...(music.artwork ? {} : { background: gradientFor(music.title) }),
            }}
        >
            {music.artwork ? (
                <img src={music.artwork} alt="" />
            ) : (
                <NoteIcon size={parseFloat(size) * 8} />
            )}
        </span>
    );

    if (!expanded) {
        return (
            <div className="np-isl np-isl--compact" onClick={() => setExpanded(true)}>
                <Art size="1.5em" />
                <span className="np-isl__wave">
                    <Waveform size={12} on={music.playing} />
                </span>
            </div>
        );
    }

    return (
        <>
            <div className="np-isl__backdrop" onClick={() => setExpanded(false)} />
            <div className="np-isl np-isl--expanded">
                <div className="np-isl__top" onClick={openOwner}>
                    <Art size="3.1em" />
                    <div className="np-isl__meta">
                        <div className="np-isl__title">{music.title}</div>
                        <div className="np-isl__artist">{music.artist || '—'}</div>
                    </div>
                    <span className="np-isl__wave np-isl__wave--big">
                        <Waveform size={24} on={music.playing} />
                    </span>
                </div>

                <div className="np-isl__track">
                    <span className="np-isl__fill" style={{ width: `${pct}%` }} />
                </div>
                <div className="np-isl__times">
                    <span>{fmtTime(music.position)}</span>
                    <span>{fmtTime(music.duration)}</span>
                </div>

                <div className="np-isl__ctl">
                    <button onClick={prev} disabled={!music.hasPrev}>
                        <PrevIcon size={26} />
                    </button>
                    <button className="np-isl__play" onClick={toggle}>
                        {music.playing ? <PauseIcon size={26} /> : <PlayIcon size={26} />}
                    </button>
                    <button onClick={next} disabled={!music.hasNext}>
                        <NextIcon size={26} />
                    </button>
                </div>
            </div>
        </>
    );
}