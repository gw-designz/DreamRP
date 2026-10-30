import { createPortal } from 'react-dom';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import './CameraApp.css';

import { fetchNui } from '../../utils/fetchNui';
import { pad2 } from '../../utils/misc';
import { uploadToProvider, dataURLtoBlob } from '../../utils/upload';
import { playSound } from '../../utils/sound';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { openApp, saveAvatar, setLaunchTab } from '../../store/slices/phoneSlice';
import { loadPhotos, upsertPhoto } from '../../store/slices/photosSlice';
import { setShareTo, setResumeThread, setDraftAttach } from '../../store/slices/messagesSlice';
import { setResumeGroup, setGroupDraft } from '../../store/slices/groupsSlice';
import { setCapture } from '../../store/slices/xSlice';
import { setCapture as marketSetCapture } from '../../store/slices/marketplaceSlice';
import { setEditorDraftImg } from '../../store/slices/contactsSlice';
import { FlipIcon } from './components/icons';
import { useT } from '../../i18n/useT';

const fmt = (s) => `${pad2(Math.floor(s / 60))}:${pad2(s % 60)}`;

const SELFIE_SHIFT = -0.13;

const GridIcon = () => (
    <svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" stroke="currentColor" strokeWidth="2">
        <rect x="3" y="3" width="18" height="18" rx="2" />
        <path d="M9 3v18M15 3v18M3 9h18M3 15h18" />
    </svg>
);

const ExpandIcon = () => (
    <svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
        <path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5" />
    </svg>
);

export default function CameraApp() {
    const dispatch = useDispatch();
    const t = useT();
    const items = useSelector((s) => s.photos.items);
    const shareTo = useSelector((s) => s.messages.shareTo);
    const shareToRef = useRef(shareTo);
    shareToRef.current = shareTo;
    const avatarShot = shareTo === 'profile' || shareTo === 'contact';

    const [mode, setMode] = useState('photo');
    const [recording, setRecording] = useState(false);
    const [elapsed, setElapsed] = useState(0);
    const [busy, setBusy] = useState(false);
    const [flash, setFlash] = useState(false);
    const [preview, setPreview] = useState(null);
    const [previewSaved, setPreviewSaved] = useState(false);

    useEffect(() => {
        if (avatarShot) setMode('photo');
    }, [avatarShot]);

    useEffect(() => {
        fetchNui('phone:camera:framing', { active: !preview }, {});
    }, [preview]);

    const feedRef = useRef(null);
    const recCanvasRef = useRef(null);
    const copyRafRef = useRef(0);
    const cfgRef = useRef(null);
    const recRef = useRef(null);
    const chunksRef = useRef([]);
    const recStartRef = useRef(0);

    const micStreamRef = useRef(null);
    const audioCtxRef = useRef(null);
    const audioGainRef = useRef(null);
    const gateRef = useRef(false);

    const last = useMemo(() => [...items].sort((a, b) => (b.ts || 0) - (a.ts || 0))[0], [items]);

    useEffect(() => {
        (async () => {
            const res = await fetchNui('phone:camera:enter', {}, {});
            if (res && res.camera) cfgRef.current = res.camera;
        })();
        dispatch(loadPhotos());
        try {
            const wc = document.createElement('canvas');
            wc.width = 16;
            wc.height = 16;
            wc.getContext('2d').fillRect(0, 0, 16, 16);
            if (wc.captureStream && window.MediaRecorder) {
                const ws = wc.captureStream(1);
                const wmime = MediaRecorder.isTypeSupported('video/webm;codecs=vp8')
                    ? 'video/webm;codecs=vp8'
                    : 'video/webm';
                const wrec = new MediaRecorder(ws, { mimeType: wmime });
                wrec.start();
                setTimeout(() => {
                    try {
                        wrec.stop();
                    } catch (e) {}
                    ws.getTracks().forEach((tr) => tr.stop());
                }, 150);
            }
        } catch (e) {}
        return () => {
            if (recRef.current && recRef.current.state !== 'inactive') recRef.current.stop();
            cancelAnimationFrame(copyRafRef.current);
            stopSelfMic();
            fetchNui('phone:camera:exit', {}, {});
            dispatch(setShareTo(null));
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    useEffect(() => {
        let stopped = false;
        let tries = 0;
        const attach = () => {
            if (stopped) return;
            const mr = window.MainRender;
            if (mr && feedRef.current) {
                mr.renderToTarget(feedRef.current);
                return;
            }
            if (tries++ < 60) setTimeout(attach, 100);
        };
        attach();
        return () => {
            stopped = true;
            if (window.MainRender) window.MainRender.stop();
        };
    }, []);

    useEffect(() => {
        fetchNui('phone:camera:mode', { mode }, {});
        if (window.MainRender && window.MainRender.setShift) window.MainRender.setShift(0);
    }, [mode]);

    useEffect(() => {
        if (!recording) {
            setElapsed(0);
            return;
        }
        const id = setInterval(() => setElapsed((e) => e + 1), 1000);
        return () => clearInterval(id);
    }, [recording]);

    useNuiEvent('phone:camera:talk', (d) => {
        const gain = audioGainRef.current;
        const ctx = audioCtxRef.current;
        if (!gain || !ctx || !gateRef.current) return;
        const now = ctx.currentTime;
        gain.gain.cancelScheduledValues(now);
        gain.gain.setTargetAtTime(d && d.talking ? 1 : 0, now, 0.02);
    });

    const routeShare = (url, type) => {
        const to = shareToRef.current;
        if (!to) return;
        dispatch(setShareTo(null));
        if (to === 'x' || to === 'xedit') {
            dispatch(setCapture({ url, type }));
            dispatch(openApp('twexa'));
            return;
        }
        if (to === 'market') {
            dispatch(marketSetCapture({ url, type }));
            dispatch(openApp('marketplace'));
            return;
        }
        if (String(to).startsWith('g:')) {
            const gid = String(to).slice(2);
            dispatch(setGroupDraft({ gid, attach: { type, url } }));
            dispatch(setResumeGroup(gid));
        } else {
            dispatch(setDraftAttach({ number: to, attach: { type, url } }));
            dispatch(setResumeThread(to));
        }
        dispatch(openApp('message'));
    };

    const saveAndRoute = async (url, type, duration) => {
        if (!url) return;
        const to = shareToRef.current;
        if (to === 'profile') {
            dispatch(setShareTo(null));
            dispatch(saveAvatar(url));
            dispatch(setLaunchTab('profile'));
            dispatch(openApp('settings'));
            return;
        }
        if (to === 'contact') {
            dispatch(setShareTo(null));
            dispatch(setEditorDraftImg(url));
            dispatch(openApp('call'));
            return;
        }
        const photo = await fetchNui('phone:camera:save', { url, type, duration }, null);
        if (photo) dispatch(upsertPhoto(photo));
        else console.error('[camera] save returned no photo for', url);
        routeShare(url, type);
    };

    const takePhoto = async () => {
        const canvas = feedRef.current;
        if (busy || !canvas) return;
        setBusy(true);
        setFlash(true);
        playSound('photosound.mp3');
        setTimeout(() => setFlash(false), 180);

        try {
            const blob = dataURLtoBlob(canvas.toDataURL('image/jpeg', 0.85));
            const url = await uploadToProvider(blob, 'photo.jpg', cfgRef.current);
            if (url) {
                const to = shareToRef.current;
                if (to && to !== 'profile' && to !== 'contact') {
                    setPreviewSaved(false);
                    setPreview({ url, type: 'image' });
                } else {
                    await saveAndRoute(url, 'image');
                }
            }
        } catch (e) {
            console.error('[camera] takePhoto failed', e);
        }
        setBusy(false);
    };

    const retakePreview = () => {
        setPreview(null);
        setPreviewSaved(false);
    };

    const savePreview = async () => {
        if (!preview || previewSaved) return;
        const photo = await fetchNui(
            'phone:camera:save',
            { url: preview.url, type: preview.type },
            null,
        );
        if (photo) dispatch(upsertPhoto(photo));
        setPreviewSaved(true);
    };

    const usePreview = () => {
        const p = preview;
        setPreview(null);
        setPreviewSaved(false);
        if (p) routeShare(p.url, p.type);
    };

    const startSelfMic = async (gate) => {
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) return null;
        try {
            const stream = await navigator.mediaDevices.getUserMedia({
                audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
            });
            const Ctx = window.AudioContext || window.webkitAudioContext;
            if (!Ctx) {
                stream.getTracks().forEach((tr) => tr.stop());
                return null;
            }
            const ctx = new Ctx();
            const srcNode = ctx.createMediaStreamSource(stream);
            const gain = ctx.createGain();
            gain.gain.value = gate ? 0 : 1;
            const dest = ctx.createMediaStreamDestination();
            srcNode.connect(gain);
            gain.connect(dest);
            micStreamRef.current = stream;
            audioCtxRef.current = ctx;
            audioGainRef.current = gain;
            gateRef.current = !!gate;
            return dest.stream.getAudioTracks()[0] || null;
        } catch (e) {
            return null;
        }
    };

    const stopSelfMic = () => {
        try {
            if (micStreamRef.current) micStreamRef.current.getTracks().forEach((tr) => tr.stop());
        } catch (_) {}
        try {
            if (audioCtxRef.current && audioCtxRef.current.state !== 'closed')
                audioCtxRef.current.close();
        } catch (_) {}
        micStreamRef.current = null;
        audioCtxRef.current = null;
        audioGainRef.current = null;
        gateRef.current = false;
    };

    const startRec = async () => {
        const canvas = feedRef.current;
        if (!canvas) return;

        let rc = recCanvasRef.current;
        if (!rc) {
            rc = document.createElement('canvas');
            recCanvasRef.current = rc;
        }
        rc.width = canvas.width || 720;
        rc.height = canvas.height || 1280;
        const rctx = rc.getContext('2d');
        const copyFrame = () => {
            if (recCanvasRef.current !== rc) return;
            if (canvas.width && rc.width !== canvas.width) rc.width = canvas.width;
            if (canvas.height && rc.height !== canvas.height) rc.height = canvas.height;
            try {
                rctx.drawImage(canvas, 0, 0);
            } catch (e) {}
            copyRafRef.current = requestAnimationFrame(copyFrame);
        };
        copyFrame();

        if (!rc.captureStream) {
            cancelAnimationFrame(copyRafRef.current);
            return;
        }
        let videoStream;
        try {
            videoStream = rc.captureStream(30);
        } catch (e) {
            cancelAnimationFrame(copyRafRef.current);
            return;
        }
        const audioTrack = await startSelfMic(true);
        await fetchNui('phone:camera:videoStart', {}, null);

        const tracks = videoStream.getVideoTracks();
        const stream = new MediaStream(audioTrack ? [...tracks, audioTrack] : [...tracks]);

        let mime = 'video/webm;codecs=vp8,opus';
        if (!audioTrack || (window.MediaRecorder && !MediaRecorder.isTypeSupported(mime)))
            mime = 'video/webm';
        let rec;
        try {
            rec = new MediaRecorder(stream, { mimeType: mime, videoBitsPerSecond: 1500000 });
        } catch (e) {
            stopSelfMic();
            return;
        }
        chunksRef.current = [];
        rec.ondataavailable = (e) => {
            if (e.data && e.data.size > 0) chunksRef.current.push(e.data);
        };
        rec.onstop = async () => {
            const duration = Math.round((Date.now() - recStartRef.current) / 1000);
            stopSelfMic();
            const blob = new Blob(chunksRef.current, { type: 'video/webm' });
            const url = await uploadToProvider(blob, 'video.webm', cfgRef.current);
            fetchNui('phone:camera:videoStop', {}, null);
            await saveAndRoute(url, 'video', duration);
        };
        recStartRef.current = Date.now();
        rec.start();
        recRef.current = rec;
        setRecording(true);
    };

    const stopRec = () => {
        const rec = recRef.current;
        if (rec && rec.state !== 'inactive') rec.stop();
        recRef.current = null;
        cancelAnimationFrame(copyRafRef.current);
        setRecording(false);
    };

    const toggleVideo = () => (recording ? stopRec() : startRec());

    const onShutter = () => (mode === 'photo' ? takePhoto() : toggleVideo());

    const backToChat = () => {
        const to = shareToRef.current;
        dispatch(setShareTo(null));
        if (to === 'profile') {
            dispatch(setLaunchTab('profile'));
            dispatch(openApp('settings'));
            return;
        }
        if (to === 'contact') {
            dispatch(openApp('call'));
            return;
        }
        if (to === 'x' || to === 'xedit') {
            dispatch(openApp('twexa'));
            return;
        }
        if (to === 'market') {
            dispatch(openApp('marketplace'));
            return;
        }
        if (to) {
            if (String(to).startsWith('g:')) dispatch(setResumeGroup(String(to).slice(2)));
            else dispatch(setResumeThread(to));
        }
        dispatch(openApp('message'));
    };

    // NoPixel extras: 3x3 grid and a fullscreen mode (phone hidden, controls over the game view)
    const [grid, setGrid] = useState(false);
    const [full, setFull] = useState(false);
    const [hideUi, setHideUi] = useState(false);
    const fullRef = useRef(false);
    fullRef.current = full;
    const shutterRef = useRef(onShutter);
    shutterRef.current = onShutter;

    useEffect(() => {
        document.body.classList.toggle('np-camfull-on', full);
        return () => document.body.classList.remove('np-camfull-on');
    }, [full]);

    useEffect(() => {
        const onKey = (e) => {
            if (!fullRef.current || e.repeat) return;
            const tag = e.target && e.target.tagName;
            if (tag === 'INPUT' || tag === 'TEXTAREA') return;
            const k = e.key.toLowerCase();
            if (k === 'escape' || k === 'backspace') setFull(false);
            else if (k === 'f') flipRef.current();
            else if (k === 'h') setHideUi((v) => !v);
            else if (k === 'g') setGrid((v) => !v);
            else if (k === 'enter' || k === ' ') shutterRef.current();
            else return;
            e.preventDefault();
            e.stopImmediatePropagation();
        };
        window.addEventListener('keydown', onKey, true);
        return () => window.removeEventListener('keydown', onKey, true);
    }, []);

    const flip = async () => {
        const res = await fetchNui('phone:camera:flip', {}, { front: false });
        const front = !!(res && res.front);
        if (window.MainRender && window.MainRender.setShift) {
            window.MainRender.setShift(front && mode === 'photo' ? SELFIE_SHIFT : 0);
        }
    };

    const flipRef = useRef(flip);
    flipRef.current = flip;

    return (
        <div className="camera">
            <canvas className="camera__feed" ref={feedRef} />
            {grid && <div className="camera__grid" />}
            {flash && <div className="camera__flash" />}

            <div className="camera__topbar" />

            {!recording && !preview && (
                <div className="camera__tools">
                    <button className={grid ? 'is-on' : ''} onClick={() => setGrid((v) => !v)} aria-label="Grid">
                        <GridIcon />
                    </button>
                    <button onClick={() => setFull(true)} aria-label="Fullscreen" title="Fullscreen">
                        <ExpandIcon />
                    </button>
                </div>
            )}

            {full &&
                createPortal(
                    <div className={`np-camfull${hideUi ? ' is-bare' : ''}`} onClick={() => shutterRef.current()}>
                        {grid && <div className="np-camfull__grid" />}
                        {flash && <div className="np-camfull__flash" />}
                        {!hideUi && (
                            <>
                                <div className="np-camfull__side np-camfull__side--left" onClick={(e) => e.stopPropagation()}>
                                    <button className={grid ? 'is-on' : ''} onClick={() => setGrid((v) => !v)} aria-label="Grid">
                                        <GridIcon />
                                    </button>
                                </div>
                                <div className="np-camfull__side" onClick={(e) => e.stopPropagation()}>
                                    <button onClick={flip} aria-label="Flip">
                                        <FlipIcon />
                                    </button>
                                    <button className={`np-camfull__shutter${recording ? ' is-rec' : ''}`} onClick={onShutter} aria-label="Shutter" />
                                    <button onClick={() => setFull(false)} aria-label="Exit fullscreen">
                                        <ExpandIcon />
                                    </button>
                                </div>
                                <div className="np-camfull__legend">
                                    <span><i>Click</i> SHUTTER</span>
                                    <span><i>RMB</i> LOOK</span>
                                    <span><i>F</i> FLIP</span>
                                    <span><i>G</i> GRID</span>
                                    <span><i>H</i> HIDE UI</span>
                                    <span><i>ESC</i> EXIT</span>
                                </div>
                            </>
                        )}
                    </div>,
                    document.body,
                )}

            {shareTo && !recording && !preview && (
                <button className="camera__cancel" onClick={backToChat}>
                    {t('camera.cancel')}
                </button>
            )}

            {mode === 'video' && (
                <div className={`camera__rec${recording ? ' is-recording' : ''}`}>
                    <span className="camera__recdot" />
                    {fmt(elapsed)}
                </div>
            )}

            <div className="camera__bottombar">
                {!recording && !avatarShot && (
                    <div className="camera__modes">
                        <button
                            className={mode === 'photo' ? 'is-active' : ''}
                            onClick={() => setMode('photo')}
                        >
                            {t('camera.photo')}
                        </button>
                        <button
                            className={mode === 'video' ? 'is-active' : ''}
                            onClick={() => setMode('video')}
                        >
                            {t('camera.video')}
                        </button>
                    </div>
                )}

                <div className="camera__row">
                    <button
                        className="camera__thumb"
                        onClick={() => dispatch(openApp('photos'))}
                        style={{ visibility: recording ? 'hidden' : 'visible' }}
                        aria-label="Open Photos"
                    >
                        {last ? (
                            last.type === 'video' ? (
                                <video src={last.url} muted />
                            ) : (
                                <img src={last.url} alt="" />
                            )
                        ) : null}
                    </button>

                    <button
                        className={`camera__shutter camera__shutter--${mode}${recording ? ' is-recording' : ''}`}
                        onClick={onShutter}
                        aria-label="Shutter"
                    >
                        <span className="camera__shutter-inner" />
                    </button>

                    <button className="camera__flip" onClick={flip} aria-label="Flip camera">
                        <FlipIcon />
                    </button>
                </div>
            </div>

            {preview && (
                <div className="camera__preview">
                    <img className="camera__preview-img" src={preview.url} alt="" />
                    <button className="camera__preview-retake" onClick={retakePreview}>
                        {t('camera.retake')}
                    </button>
                    <div className="camera__preview-bar">
                        <button
                            className="camera__preview-save"
                            onClick={savePreview}
                            disabled={previewSaved}
                        >
                            {previewSaved ? t('camera.saved') : t('camera.savePhoto')}
                        </button>
                        <button className="camera__preview-use" onClick={usePreview}>
                            {t('camera.usePhoto')}
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}