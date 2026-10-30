const STUN_SERVERS = [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' },
    { urls: 'stun:stun.cloudflare.com:3478' },
];

const CONNECT_TIMEOUT = 8000;

let pc = null;
let sendSignal = null;
let onRemote = null;
let onFallback = null;
let pending = [];
let watchdog = null;
let settled = false;

function giveUp() {
    if (settled) return;
    settled = true;
    clearTimeout(watchdog);
    watchdog = null;
    const cb = onFallback;
    closePeer();
    if (cb) cb();
}

function succeed() {
    if (settled) return;
    settled = true;
    clearTimeout(watchdog);
    watchdog = null;
}

function closePeer() {
    if (pc) {
        try {
            pc.ontrack = null;
            pc.onicecandidate = null;
            pc.oniceconnectionstatechange = null;
            pc.onconnectionstatechange = null;
            pc.close();
        } catch (e) {}
        pc = null;
    }
    pending = [];
}

function handleSignal(raw) {
    if (!pc) {
        pending.push(raw);
        return;
    }
    let m;
    try {
        m = typeof raw === 'string' ? JSON.parse(raw) : raw;
    } catch (e) {
        return;
    }
    if (!m) return;

    if (m.kind === 'offer') {
        pc.setRemoteDescription(m.sdp)
            .then(() => pc.createAnswer())
            .then((ans) => pc.setLocalDescription(ans))
            .then(
                () =>
                    sendSignal &&
                    sendSignal(JSON.stringify({ kind: 'answer', sdp: pc.localDescription })),
            )
            .catch((e) => console.error('[videoCall] offer handling failed', e));
    } else if (m.kind === 'answer') {
        pc.setRemoteDescription(m.sdp).catch((e) => console.error('[videoCall] answer failed', e));
    } else if (m.kind === 'ice' && m.candidate) {
        pc.addIceCandidate(m.candidate).catch(() => {});
    }
}

export function startVideoCall({ role, localStream, onRemoteStream, send, onRelayNeeded }) {
    stopVideoCall();
    sendSignal = send;
    onRemote = onRemoteStream;
    onFallback = onRelayNeeded;
    settled = false;

    try {
        pc = new RTCPeerConnection({ iceServers: STUN_SERVERS });
    } catch (e) {
        console.error('[videoCall] RTCPeerConnection unavailable', e);
        giveUp();
        return;
    }

    if (localStream) {
        localStream.getVideoTracks().forEach((tr) => pc.addTrack(tr, localStream));
    }
    pc.ontrack = (e) => {
        if (onRemote && e.streams && e.streams[0]) onRemote(e.streams[0]);
    };
    pc.onicecandidate = (e) => {
        if (e.candidate && sendSignal)
            sendSignal(JSON.stringify({ kind: 'ice', candidate: e.candidate }));
    };
    const check = () => {
        if (!pc) return;
        const st = pc.connectionState || pc.iceConnectionState;
        if (st === 'connected' || st === 'completed') succeed();
        else if (st === 'failed') giveUp();
    };
    pc.oniceconnectionstatechange = check;
    pc.onconnectionstatechange = check;

    watchdog = setTimeout(giveUp, CONNECT_TIMEOUT);

    if (role === 'offer') {
        pc.createOffer({ offerToReceiveVideo: true })
            .then((off) => pc.setLocalDescription(off))
            .then(
                () =>
                    sendSignal &&
                    sendSignal(JSON.stringify({ kind: 'offer', sdp: pc.localDescription })),
            )
            .catch((e) => console.error('[videoCall] offer failed', e));
    }

    const q = pending;
    pending = [];
    q.forEach(handleSignal);
}

export function onVideoSignal(blob) {
    handleSignal(blob);
}

export function stopVideoCall() {
    clearTimeout(watchdog);
    watchdog = null;
    settled = true;
    closePeer();
    sendSignal = null;
    onRemote = null;
    onFallback = null;
}