import { useEffect } from 'react';
import useStore from '../state/store';

const WindowListener = ({ children }) => {
    const setState = useStore((s) => s.setState);

    useEffect(() => {
        const onKey = (event) => {
            if (event.key !== 'Escape') return;
            useStore.getState().hide();
        };
        window.addEventListener('keydown', onKey);
        return () => window.removeEventListener('keydown', onKey);
    }, []);

    useEffect(() => {
        const onMessage = (event) => {
            const payload = event.data;
            if (!payload || !payload.type) return;
            setState(payload);
        };
        window.addEventListener('message', onMessage);
        return () => window.removeEventListener('message', onMessage);
    }, [setState]);

    return children;
};

export default WindowListener;
