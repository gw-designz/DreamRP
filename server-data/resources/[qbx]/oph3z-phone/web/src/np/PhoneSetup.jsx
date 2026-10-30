// First-open Phone Setup. Shown over everything until the character has picked a bank
// provider (settings.bank), which then brands the Bank app. Disable with Config.UI.PhoneSetup.
import { useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { faCheck, faChevronLeft } from '@fortawesome/free-solid-svg-icons';
import FaIcon from './FaIcon';
import { saveSetting } from '../store/slices/settingsSlice';
import { BANKS, BankMark, bankVars, getBank } from './banks';
import { useBack } from './ui/kit';
import './PhoneSetup.css';

export default function PhoneSetup() {
    const dispatch = useDispatch();
    const name = useSelector((s) => s.phone.identity.name);
    const [step, setStep] = useState('welcome');
    const [pick, setPick] = useState(null);

    // Backspace steps back to the welcome page but never skips setup.
    useBack(() => {
        if (step === 'bank') setStep('welcome');
        return true;
    }, 10);

    const chosen = pick ? getBank(pick) : null;
    const first = (name || '').trim().split(/\s+/)[0];

    return (
        <div className="pss" style={chosen ? bankVars(chosen) : undefined}>
            {step === 'welcome' ? (
                <div className="pss-page pss-page--welcome" key="welcome">
                    <div className="pss-hello">Hello</div>
                    <div className="pss-title">{first ? `Welcome, ${first}` : 'Welcome'}</div>
                    <p className="pss-sub">Let’s get your new phone set up. It only takes a moment.</p>
                    <button className="pss-btn" onClick={() => setStep('bank')}>
                        Get Started
                    </button>
                </div>
            ) : (
                <div className="pss-page" key="bank">
                    <button className="pss-back" data-np-back onClick={() => setStep('welcome')} aria-label="Back">
                        <FaIcon icon={faChevronLeft} />
                    </button>
                    <div className="pss-step">Phone Setup</div>
                    <div className="pss-title">Choose your bank</div>
                    <p className="pss-sub">Your Bank app will use this provider’s look. You can change it later in Settings.</p>

                    <div className="pss-banks">
                        {BANKS.map((b) => (
                            <button
                                key={b.id}
                                className={`pss-bank${pick === b.id ? ' is-on' : ''}`}
                                style={bankVars(b)}
                                onClick={() => setPick(b.id)}
                            >
                                <span className="pss-bank__mark">
                                    <BankMark bank={b} />
                                </span>
                                <span className="pss-bank__main">
                                    <span className="pss-bank__name">{b.lines.join(' ')}</span>
                                    <span className="pss-bank__tag">{b.tagline}</span>
                                </span>
                                <span className="pss-bank__check">{pick === b.id && <FaIcon icon={faCheck} />}</span>
                            </button>
                        ))}
                    </div>

                    <button
                        className="pss-btn pss-btn--bank"
                        disabled={!chosen}
                        onClick={() => dispatch(saveSetting('bank', chosen.id))}
                    >
                        {chosen ? `Continue with ${chosen.name}` : 'Select a bank'}
                    </button>
                </div>
            )}
        </div>
    );
}
