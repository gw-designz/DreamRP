import { createRoot } from 'react-dom/client';
import { Desktop } from './Desktop';
import { KeyHints } from './KeyHints';
import { isDui, isPreview, nui } from './api';
import { installDuiInput, installKeyRelay } from './dui';
import { installButtonSounds } from './sounds';
import '@fontsource/poppins/latin-400.css';
import '@fontsource/poppins/latin-500.css';
import '@fontsource/poppins/latin-600.css';
import '@fontsource/poppins/latin-700.css';
import '@fontsource/bebas-neue/latin-400.css';
import '@fontsource/barlow-semi-condensed/latin-800-italic.css';
import './styles.css';
import './shell.css';
import './news/news.css';
import './radial.css';

installButtonSounds();
if (isDui) installDuiInput(active => void nui('typing', { active }));
else if (!isPreview) installKeyRelay(keys => nui('keys', { keys }));

createRoot(document.getElementById('root')!).render(<><Desktop />{!isDui && <KeyHints />}</>);
