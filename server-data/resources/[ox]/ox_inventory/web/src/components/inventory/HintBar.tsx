import React from 'react';
import { fetchNui } from '../../utils/fetchNui';
import { Locale } from '../../store/locale';

const Mouse: React.FC<{ button: 'left' | 'right' }> = ({ button }) => (
  <svg className="hint-mouse" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
    <path
      fill="none"
      stroke="currentColor"
      strokeWidth="1.800"
      d="M12 2.500c-3.300 0-6 2.500-6 6v7c0 3.300 2.700 6 6 6s6-2.700 6-6v-7c0-3.500-2.700-6-6-6z"
    />
    <path
      fill="currentColor"
      d={
        button === 'left' ? 'M12 3v7H6.500V8.500C6.500 5.500 9 3 12 3z' : 'M12 3v7h5.500V8.500C17.500 5.500 15 3 12 3z'
      }
    />
  </svg>
);

const HintBar: React.FC = () => (
  <div className="hint-bar">
    <div className="hint">
      <Mouse button="left" />
      <span>{Locale.ui_hint_pickup || 'Pick up'}</span>
    </div>
    <i />
    <div className="hint">
      <Mouse button="right" />
      <span>{Locale.ui_hint_context || 'Context menu'}</span>
    </div>
    <i />
    <div className="hint hint-alt">
      <kbd>ALT</kbd>
      <b>+</b>
      <Mouse button="left" />
      <span>{Locale.ui_hint_use || 'Use item'}</span>
    </div>
    <i />
    <div className="hint">
      <kbd>CTRL</kbd>
      <b>+</b>
      <Mouse button="left" />
      <span>{Locale.ui_hint_quickmove || 'Quick move'}</span>
    </div>
    <i />
    <button className="hint hint-close" onClick={() => fetchNui('exit')}>
      <kbd>ESC</kbd>
      <span>{Locale.ui_close || 'Close'}</span>
    </button>
  </div>
);

export default HintBar;
