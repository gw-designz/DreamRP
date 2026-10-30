import React, { useEffect } from 'react';
import ReactDOM from 'react-dom/client';
import { AnimatePresence } from 'framer-motion';

import Groups from './components/Groups';
import WindowListener from './utils/windowlistener';
import useStore from './state/store';
import isEnvBrowser from './utils/isEnvBrowser';

import './style.css';

export function App() {
    const visible = useStore((s) => s.visible);
    const loadMock = useStore((s) => s.loadMock);

    useEffect(() => {
        if (isEnvBrowser()) {
            loadMock();
        }
    }, [loadMock]);

    return (
        <WindowListener>
            <AnimatePresence>{visible && <Groups/>}</AnimatePresence>
        </WindowListener>
    );
}

const rootElement = document.getElementById('app');
if (rootElement) {
    ReactDOM.createRoot(rootElement).render(<App />);
}
