// Bank (Fleeca, Pacific Standard or Paleto, picked in Phone Setup). Front end for the existing Wallet backend: balance, transfers,
// invoices/bills and transaction history all go through server/app/wallet.
import { useEffect, useMemo, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
    faHouse,
    faRightLeft,
    faFileInvoiceDollar,
    faMoneyBillTransfer,
    faUser,
    faArrowRight,
    faChevronLeft,
    faChevronRight,
    faCopy,
} from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { loadWallet, sendMoney, payBill, refreshBills } from '../../../store/slices/walletSlice';
import { pushToast } from '../../../store/slices/toastSlice';
import { copyText } from '../../../utils/clipboard';
import { getBank, bankVars, BankLogo } from '../../banks';
import { NpApp, TabBar, SearchBox, Empty, Btn, Msg, money, ago, mdy, useStatusTone } from '../../ui/kit';
import './bank.css';

const TABS = [
    { id: 'home', icon: faHouse, label: 'Home' },
    { id: 'transfer', icon: faRightLeft, label: 'Transfer' },
    { id: 'bills', icon: faFileInvoiceDollar, label: 'Invoices' },
    { id: 'history', icon: faMoneyBillTransfer, label: 'Transactions' },
    { id: 'account', icon: faUser, label: 'Account' },
];

const REASONS = {
    amount: 'Enter an amount above $0.',
    funds: 'Insufficient funds.',
    notfound: 'No account found for that ID or number.',
    self: 'You can’t transfer to yourself.',
    bad: 'Check the recipient.',
    failed: 'Transfer failed. You were not charged.',
};

function txSign(tx) {
    return tx.kind === 'received' || tx.kind === 'income' || tx.kind === 'refund' ? '+' : '-';
}

export function TxRow({ tx }) {
    const sign = txSign(tx);
    return (
        <div className="bank-tx">
            <span className="bank-tx__ico">
                <FaIcon icon={faMoneyBillTransfer} />
            </span>
            <span className="bank-tx__main">
                <span className="bank-tx__party">{tx.party || 'Transaction'}</span>
                <span className="bank-tx__note">{tx.note || (tx.kind === 'bill' ? 'Bill payment' : tx.kind)}</span>
            </span>
            <span className="bank-tx__end">
                <span className={`bank-tx__amt${sign === '+' ? ' is-in' : ''}`}>
                    {sign} {money(tx.amount, !Number.isInteger(Number(tx.amount)))}
                </span>
                <span className="bank-tx__time">{ago(tx.ts)}</span>
            </span>
        </div>
    );
}

export default function BankApp() {
    const dispatch = useDispatch();
    const wallet = useSelector((s) => s.wallet);
    const identity = useSelector((s) => s.phone.identity);
    const bank = getBank(useSelector((s) => s.settings.bank));
    const [tab, setTab] = useState('home');
    const [q, setQ] = useState('');
    useStatusTone('light');

    useEffect(() => {
        dispatch(loadWallet());
    }, [dispatch]);

    useEffect(() => {
        if (tab === 'bills') dispatch(refreshBills());
    }, [tab, dispatch]);

    const accountId = wallet.accountId || identity.citizenid || '—';
    const filtered = useMemo(() => {
        const n = q.trim().toLowerCase();
        if (!n) return wallet.transactions;
        return wallet.transactions.filter((t) =>
            `${t.party || ''} ${t.note || ''} ${t.amount}`.toLowerCase().includes(n),
        );
    }, [wallet.transactions, q]);

    return (
        <NpApp theme="light" className={`bank bank--${bank.id}`} style={bankVars(bank)}>
            <div className="bank-head">
                <div className="bank-head__row">
                    <BankLogo bank={bank} />
                    <SearchBox
                        value={q}
                        onChange={(v) => {
                            setQ(v);
                            if (v && tab !== 'history') setTab('history');
                        }}
                        className="bank-search"
                    />
                </div>
                <div className="bank-card">
                    <div className="bank-card__kind">Personal</div>
                    <div className="bank-card__label">Current Balance</div>
                    <div className="bank-card__bal">{wallet.loaded ? money(wallet.balance, true) : '—'}</div>
                    <div className="bank-card__label">Personal</div>
                    <div className="bank-card__label">Account ID: {accountId}</div>
                </div>
                <div className="bank-pager">
                    <FaIcon icon={faChevronLeft} />
                    <span />
                    <FaIcon icon={faChevronRight} />
                </div>
            </div>

            <div className="bank-body">
                {tab === 'home' && (
                    <>
                        <h2 className="bank-h">Latest Transactions</h2>
                        {wallet.transactions.length === 0 ? (
                            <Empty title="No transactions yet" />
                        ) : (
                            <div className="bank-list">
                                {wallet.transactions.slice(0, 3).map((tx) => (
                                    <TxRow key={tx.id} tx={tx} />
                                ))}
                                <button className="bank-seeall" onClick={() => setTab('history')}>
                                    See All <FaIcon icon={faArrowRight} />
                                </button>
                            </div>
                        )}
                    </>
                )}
                {tab === 'transfer' && <Transfer onDone={() => setTab('home')} />}
                {tab === 'bills' && <Bills bills={wallet.bills} onPay={(id) => dispatch(payBill(id))} />}
                {tab === 'history' && (
                    <>
                        <h2 className="bank-h">{q ? `Results for “${q}”` : 'Transactions'}</h2>
                        {filtered.length === 0 ? (
                            <Empty title={q ? 'No matches' : 'No transactions yet'} />
                        ) : (
                            <div className="bank-list">
                                {filtered.map((tx) => (
                                    <TxRow key={tx.id} tx={tx} />
                                ))}
                            </div>
                        )}
                    </>
                )}
                {tab === 'account' && (
                    <>
                        <h2 className="bank-h">Account</h2>
                        <div className="bank-list">
                            <Info k="Account holder" v={identity.name} />
                            <Info
                                k="Account ID"
                                v={accountId}
                                copy={() => {
                                    copyText(String(accountId));
                                    dispatch(pushToast({ title: 'Bank', body: 'Account ID copied.' }));
                                }}
                            />
                            <Info k="Phone number" v={identity.number} />
                            <Info k="Account type" v="Personal" />
                        </div>
                        <p className="bank-note">People can send you money with your Account ID or your phone number.</p>
                    </>
                )}
            </div>

            <TabBar variant="bubble" tabs={TABS} active={tab} onChange={setTab} className="bank-tabs" />
        </NpApp>
    );
}

function Info({ k, v, copy }) {
    return (
        <div className="bank-info">
            <span>{k}</span>
            <b>{v || '—'}</b>
            {copy && (
                <button onClick={copy} aria-label="Copy">
                    <FaIcon icon={faCopy} />
                </button>
            )}
        </div>
    );
}

function Transfer({ onDone }) {
    const dispatch = useDispatch();
    const [to, setTo] = useState('');
    const [amount, setAmount] = useState('');
    const [note, setNote] = useState('');
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const amt = Math.floor(Number(amount) || 0);

    const submit = async () => {
        if (!to.trim()) return setErr('Enter an Account ID or phone number.');
        if (amt <= 0) return setErr(REASONS.amount);
        setBusy(true);
        setErr('');
        const res = await dispatch(sendMoney({ to: to.trim(), amount: amt, note: note.trim() }));
        setBusy(false);
        if (res && res.ok) {
            dispatch(pushToast({ title: 'Bank', body: `Sent ${money(amt)}.` }));
            onDone();
        } else setErr(REASONS[res && res.reason] || 'Transfer failed.');
    };

    return (
        <>
            <h2 className="bank-h">Transfer</h2>
            <div className="bank-form">
                <input className="bank-in" value={to} maxLength={32} placeholder="Account ID or phone number" onChange={(e) => setTo(e.target.value)} />
                <input
                    className="bank-in"
                    value={amount}
                    inputMode="numeric"
                    placeholder="Amount"
                    onChange={(e) => setAmount(e.target.value.replace(/[^0-9]/g, '').slice(0, 10))}
                />
                <input className="bank-in" value={note} maxLength={80} placeholder="Comment" onChange={(e) => setNote(e.target.value)} />
                <Msg>{err}</Msg>
                <Btn className="bank-confirm" onClick={submit} busy={busy}>
                    Confirm
                </Btn>
            </div>
        </>
    );
}

function Bills({ bills, onPay }) {
    const [busy, setBusy] = useState(null);
    const unpaid = bills.filter((b) => !b.paid);
    const paid = bills.filter((b) => b.paid);
    return (
        <>
            <h2 className="bank-h">Invoices</h2>
            {bills.length === 0 && <Empty title="No invoices" body="Bills sent to you will show up here." />}
            <div className="bank-list">
                {[...unpaid, ...paid].map((b) => (
                    <div key={b.id} className={`bank-bill${b.paid ? ' is-paid' : ''}`}>
                        <span className="bank-tx__main">
                            <span className="bank-tx__party">{b.issuer || 'Invoice'}</span>
                            <span className="bank-tx__note">
                                {b.label} · {mdy(b.ts)}
                            </span>
                        </span>
                        <span className="bank-tx__end">
                            <span className="bank-tx__amt">{money(b.amount)}</span>
                            {b.paid ? (
                                <span className="bank-tx__time">Paid</span>
                            ) : (
                                <Btn
                                    className="npk-btn--sm"
                                    busy={busy === b.id}
                                    onClick={async () => {
                                        setBusy(b.id);
                                        await onPay(b.id);
                                        setBusy(null);
                                    }}
                                >
                                    Pay
                                </Btn>
                            )}
                        </span>
                    </div>
                ))}
            </div>
        </>
    );
}
