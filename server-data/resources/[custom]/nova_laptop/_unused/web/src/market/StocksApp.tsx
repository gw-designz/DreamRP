import { useCallback, useEffect, useRef, useState } from 'react';
import type { CSSProperties } from 'react';
import { action, isPreview } from '../api';
import { Icon } from '../icons';
import { useAutoRefresh } from '../useAutoRefresh';
import { money, percent, PriceChart, signedMoney, Sparkline } from './Chart';
import type { Activity, ChartData, MarketReply, MarketSnapshot, OrderQuote, Stock } from './types';
import './stocks.css';

const arr = <T,>(value: T[] | unknown): T[] => Array.isArray(value) ? value : [];
const normalise = (data: MarketSnapshot): MarketSnapshot => ({ ...data, quotes: arr<Stock>(data.quotes), account: { ...data.account,
  positions: arr(data.account.positions), history: arr(data.account.history), watchlist: arr(data.account.watchlist) } });
const requestId = () => crypto.randomUUID();
const navItems = [ { id: 'markets', label: 'Markets', icon: 'stocks' }, { id: 'watchlist', label: 'Watchlist', icon: 'star' },
  { id: 'portfolio', label: 'My portfolio', icon: 'portfolio' }, { id: 'activity', label: 'Activity', icon: 'history' } ] as const;
type Page = typeof navItems[number]['id'];
function Logo({ stock, small = false }: { stock: Stock; small?: boolean }) {
  return <span className={`stock-logo ${small ? 'small' : ''}`} style={{ '--stock-color': stock.color } as CSSProperties}>{stock.symbol === 'LFI' ? 'Li' : stock.symbol === 'MAZ' ? 'M' : stock.symbol === 'VAP' ? 'V' : stock.symbol === 'ROR' ? 'R' : stock.symbol === 'ECO' ? 'e' : stock.symbol === 'BNL' ? 'b' : stock.symbol === 'FLY' ? 'F' : stock.symbol === 'RWC' ? 'rw' : stock.symbol.slice(0, 2)}</span>;
}

export function StocksApp({ playerName, active, live }: { playerName: string; active: boolean; live: boolean }) {
  const [market, setMarket] = useState<MarketSnapshot | null>(null), [page, setPage] = useState<Page>('markets');
  const [selected, setSelected] = useState('LFI'), [search, setSearch] = useState(''), [sector, setSector] = useState('All');
  const [period, setPeriod] = useState('1D'), [chartStyle, setChartStyle] = useState<'line' | 'candles'>('line');
  const [chart, setChart] = useState<ChartData | null>(null), [chartError, setChartError] = useState('');
  const [loading, setLoading] = useState(true), [error, setError] = useState(''), [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false), [side, setSide] = useState<'buy' | 'sell'>('buy'), [quantity, setQuantity] = useState('1');
  const [review, setReview] = useState<OrderQuote | null>(null), [reviewError, setReviewError] = useState('');
  const [deadline, setDeadline] = useState(0), [clock, setClock] = useState(Date.now());
  const [funds, setFunds] = useState<'deposit' | 'withdraw' | null>(null), [amount, setAmount] = useState('1000');
  const [fundsError, setFundsError] = useState(''), [receipt, setReceipt] = useState<Activity | null>(null);
  const [activityFilter, setActivityFilter] = useState('all');
  const busyRef = useRef(false), mounted = useRef(true), orderId = useRef(''), transferId = useRef('');
  const marketRef = useRef<MarketSnapshot | null>(null), latestChart = useRef(0), loadSequence = useRef(0);
  const quoteTask = useRef<() => Promise<void>>(async () => {}), quoteAttempt = useRef(0), tradeAttempt = useRef('');
  const updateQuote = useCallback(async () => { await quoteTask.current(); }, []);
  useAutoRefresh(live && !!review, updateQuote, undefined, 1000);
  useEffect(() => { mounted.current = true; return () => { mounted.current = false; }; }, []);
  const announce = (text: string) => { setNotice(text); };
  useEffect(() => { if (!notice) return; const timer = window.setTimeout(() => setNotice(''), 4500); return () => clearTimeout(timer); }, [notice]);

  const apply = useCallback((next: MarketSnapshot) => {
    const normalized = normalise(next), previous = marketRef.current;
    if (previous && previous.account.revision > normalized.account.revision) normalized.account = previous.account;
    if (previous && previous.marketRevision > normalized.marketRevision) {
      normalized.quotes = previous.quotes; normalized.marketRevision = previous.marketRevision; normalized.updatedAt = previous.updatedAt;
    }
    marketRef.current = normalized; setMarket(normalized);
  }, []);

  const refresh = useCallback(async () => {
    if (busyRef.current) return;
    const sequence = ++loadSequence.current;
    const result = await action('marketSnapshot');
    if (!mounted.current || sequence !== loadSequence.current) return;
    setLoading(false);
    if (!result.ok || !result.market) { setError(result.error || 'The exchange could not be reached.'); return; }
    apply(result.market); setError('');
  }, [apply]);

  useAutoRefresh(live, refresh);
  useEffect(() => { if (!live) return; setClock(Date.now()); const timer = window.setInterval(() => setClock(Date.now()), 500); return () => clearInterval(timer); }, [live]);
  useEffect(() => {
    if (market?.quotes.length && !market.quotes.some(stock => stock.symbol === selected)) setSelected((market.quotes.find(stock => stock.active) || market.quotes[0]).symbol);
  }, [market?.quotes, selected]);
  useEffect(() => {
    if (!active || (!review && !funds && !receipt)) return;
    const handler = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault(); event.stopImmediatePropagation();
        if (!busyRef.current) { setReview(null); setReviewError(''); setFunds(null); setReceipt(null); }
      }
      if (event.key === 'Tab') {
        const controls = Array.from(document.querySelectorAll<HTMLElement>('.invest-modal button:not(:disabled), .invest-modal input:not(:disabled)'));
        if (!controls.length) return;
        const first = controls[0], last = controls[controls.length - 1], outside = !document.activeElement?.closest('.invest-modal');
        if ((event.shiftKey && document.activeElement === first) || (!event.shiftKey && document.activeElement === last) || outside) {
          event.preventDefault(); (event.shiftKey ? last : first).focus();
        }
      }
    };
    window.addEventListener('keydown', handler, true);
    return () => window.removeEventListener('keydown', handler, true);
  }, [review, funds, receipt, active]);

  const getChart = useCallback(async () => {
    if (busyRef.current) return;
    const sequence = ++latestChart.current;
    const result = await action('marketChart', { symbol: selected, period });
    if (!mounted.current || sequence !== latestChart.current) return;
    if (!result.ok || !result.chart) { setChartError(result.error || 'Chart unavailable.'); return; }
    setChart({ ...result.chart, candles: arr(result.chart.candles) }); setChartError('');
  }, [selected, period]);
  useEffect(() => () => { latestChart.current++; }, [live, selected, period, page]);
  useAutoRefresh(live && (page === 'markets' || page === 'watchlist'), getChart);

  async function mutate(name: string, payload: Record<string, unknown>): Promise<MarketReply | null> {
    if (busyRef.current) return null;
    busyRef.current = true; setBusy(true); loadSequence.current++;
    const result = await action(name, payload);
    busyRef.current = false;
    if (!mounted.current) return null;
    setBusy(false); if (result.market) apply(result.market);
    return result;
  }
  function choose(symbol: string, nextPage: Page = 'markets') { setSelected(symbol); setPage(nextPage); setSearch(''); setQuantity('1'); setSide('buy'); setError(''); }
  async function toggleWatch(symbol: string) {
    if (!market) return;
    const result = await mutate('marketWatch', { symbol, watched: !market.account.watchlist.includes(symbol), revision: market.account.revision, requestId: requestId() });
    if (!result) return;
    if (!result.ok) { setError(result.error || 'Could not change watchlist.'); void refresh(); }
    else announce(result.message || 'Watchlist updated.');
  }
  async function prepareOrder(renew = false) {
    quoteAttempt.current = Date.now(); setReviewError('');
    const terms = renew && review ? { symbol: review.symbol, side: review.side, quantity: review.quantity } : { symbol: selected, side, quantity: Number(quantity) };
    const result = await mutate('marketQuote', terms);
    if (!result) return;
    if (!result.ok || !result.quote) { setReviewError(result.error || 'Could not quote this order.'); void refresh(); return; }
    orderId.current = requestId(); tradeAttempt.current = ''; setReview(result.quote);
    setDeadline(Date.now() + Math.max(0, result.quote.expiresAt - (result.serverTime || Date.now()) - 200));
  }
  async function execute() {
    if (!review || Date.now() >= deadline || busyRef.current || marketRef.current?.account.pendingTransfer) return;
    tradeAttempt.current = orderId.current;
    const result = await mutate('marketTrade', { token: review.token, requestId: orderId.current, revision: review.accountRevision });
    if (!result) return;
    if (!result.ok) { setReviewError(result.error || 'The order was not confirmed.'); void refresh(); return; }
    const activity = result.market?.account.history && arr<Activity>(result.market.account.history).find(item => item.id === orderId.current);
    tradeAttempt.current = ''; setReceipt(activity || null); setReview(null); setQuantity('1'); setReviewError(''); announce(result.message || 'Order filled.');
  }
  function openFunds(direction: 'deposit' | 'withdraw') { setFunds(direction); setFundsError(''); setAmount('1000'); transferId.current = requestId(); }
  async function transfer() {
    if (!market || !funds) return;
    const result = await mutate('marketTransfer', { direction: funds, amount: Number(amount), requestId: transferId.current, revision: market.account.revision });
    if (!result) return;
    if (!result.ok) { setFundsError(result.error || 'The transfer was not confirmed.'); void refresh(); return; }
    setFunds(null); announce(result.message || 'Transfer complete.');
  }
  const stock = market?.quotes.find(item => item.symbol === selected) || market?.quotes[0];
  const account = market?.account, position = account?.positions.find(p => p.symbol === stock?.symbol);
  const watched = !!stock && !!account?.watchlist.includes(stock.symbol);
  const quantityNumber = Number(quantity), validQuantity = Number.isInteger(quantityNumber) && quantityNumber > 0 && quantityNumber <= (market?.rules.maxOrderShares || 10000);
  const quotedPrice = stock ? side === 'buy' ? stock.askCents : stock.bidCents : 0;
  const estimatedGross = validQuantity ? quotedPrice * quantityNumber : 0;
  const estimatedFee = Math.max(market?.rules.minFeeCents ?? 1, Math.round(estimatedGross * (market?.rules.feeBps || 0) / 10000));
  const estimatedTotal = estimatedGross + (side === 'buy' ? estimatedFee : -estimatedFee);
  const cannotAfford = side === 'buy' ? estimatedTotal > (account?.cashCents || 0) : quantityNumber > (position?.quantity || 0);
  const exceedsOrderLimit = !!market && estimatedGross > market.rules.maxOrderValueCents;
  const locked = !!account?.pendingTransfer;
  const expired = !!review && (clock >= deadline || (!!market && (review.marketRevision !== market.marketRevision || review.accountRevision !== market.account.revision)));
  quoteTask.current = async () => {
    if (!review || busyRef.current || locked) return;
    if (tradeAttempt.current) {
      const filled = marketRef.current?.account.history.find(item => item.id === tradeAttempt.current);
      if (filled) { tradeAttempt.current = ''; setReceipt(filled); setReview(null); setReviewError(''); setQuantity('1'); }
      return;
    }
    if ((expired || reviewError) && Date.now() - quoteAttempt.current >= 4000) await prepareOrder(true);
  };
  const sectors = ['All', ...new Set(market?.quotes.filter(q => q.active).map(q => q.sector) || [])];
  const displayed = market?.quotes.filter(q => (sector === 'All' || q.sector === sector) && (page !== 'watchlist' || account?.watchlist.includes(q.symbol))) || [];
  const results = market?.quotes.filter(q => `${q.symbol} ${q.name} ${q.sector}`.toLowerCase().includes(search.toLowerCase())) || [];

  return <div className="invest-shell">
    <aside className="invest-sidebar"><div className="invest-brand"><span><Icon name="stocks" size={22} /></span><strong>nova<span>invest</span></strong></div><div className="invest-account-label"><span className="live-dot" />{isPreview ? 'BROWSER PREVIEW' : account?.mode === 'paper' ? 'PRACTICE ACCOUNT' : 'IN-GAME ACCOUNT'}</div>
      <nav aria-label="Investment navigation">{navItems.map(item => <button key={item.id} className={page === item.id ? 'selected' : ''} onClick={() => { setPage(item.id); setSector('All'); setReviewError(''); }}><Icon name={item.icon} size={18} />{item.label}{item.id === 'watchlist' && !!account?.watchlist.length && <small>{account.watchlist.length}</small>}</button>)}</nav>
      <div className="invest-sidebar-bottom"><div className="invest-safe-card"><Icon name="shield" size={21} /><strong>Your city. Your market.</strong><p>Fictional shares.<br />In-game money.</p></div><div className="invest-user"><span>{playerName.split(' ').map(n => n[0]).slice(0, 2).join('')}</span><div><strong>{playerName}</strong><small>Personal account</small></div></div></div>
    </aside>
    <div className="invest-workspace"><header className="invest-topbar"><label><Icon name="search" size={17} /><input aria-label="Search investments" placeholder="Search stocks, companies, sectors" value={search} onChange={event => setSearch(event.target.value)} /></label><span className="exchange-status"><i className="live-dot" />Simulated exchange</span>
      {search && <div className="investment-search-results">{results.map(q => <button key={q.symbol} onClick={() => choose(q.symbol)}><Logo stock={q} small /><span><strong>{q.name}</strong><small>{q.symbol} · {q.sector}</small></span><b>{money(q.priceCents)}</b></button>)}{!results.length && <p>No matching investments.</p>}</div>}
    </header>
    <div className="invest-content">
      {loading && !market ? <div className="invest-loading"><span className="invest-spinner" /><h2>Connecting to your market</h2><p>Loading quotes and your portfolio.</p></div> : !market ? <div className="invest-empty"><Icon name="wifi" size={34} /><h2>Let’s reconnect.</h2><p>{error}</p></div> : <>
        {error && <div className="invest-error" role="alert"><Icon name="info" size={16} /><span>{error}</span><button aria-label="Dismiss market error" onClick={() => setError('')}><Icon name="close" size={15} /></button></div>}
        {locked && <div className="invest-error reconciliation" role="alert"><Icon name="shield" size={19} /><span>A bank transfer needs staff reconciliation. Trading and transfers are locked.<small>Reference: {account!.pendingTransfer!.id}</small></span></div>}
        <div className="invest-page-heading"><div><span className="invest-eyebrow">{page === 'markets' ? 'A CLEARER VIEW OF YOUR NEXT MOVE' : page === 'portfolio' ? 'THE BIGGER PICTURE' : page === 'watchlist' ? 'KEEP YOUR FAVOURITES CLOSE' : 'EVERY MOVE, ACCOUNTED FOR'}</span><h1>{page === 'markets' ? 'Your market, in focus.' : page === 'portfolio' ? 'My portfolio' : page === 'watchlist' ? 'My watchlist' : 'Account activity'}</h1></div>{account!.mode === 'bank' && <button className="invest-primary" disabled={busy || locked} onClick={() => openFunds('deposit')}><Icon name="plus" size={16} />Add funds</button>}</div>
        <div className="portfolio-metrics"><div><span>Portfolio value <Icon name="portfolio" size={13} /></span><strong>{money(account!.equityCents)}</strong><small>Cash + current holdings</small></div><div><span>Total profit / loss <Icon name="stocks" size={13} /></span><strong className={account!.realizedPnlCents + account!.unrealizedPnlCents >= 0 ? 'positive' : 'negative'}>{signedMoney(account!.realizedPnlCents + account!.unrealizedPnlCents)}</strong><small>Realized + unrealized, after fees</small></div><div><span>Buying power <Icon name="wallet" size={13} /></span><strong>{money(account!.cashCents)}</strong><small>Available brokerage cash{account!.mode === 'bank' && <button disabled={busy || locked} onClick={() => openFunds('withdraw')}>Withdraw <Icon name="arrow" size={10} /></button>}</small></div></div>

        {(page === 'markets' || page === 'watchlist') && stock && <>
          <div className="stock-detail-grid"><section className="stock-chart-card"><header><Logo stock={stock} /><div className="stock-heading"><h2>{stock.name}</h2><span>{stock.symbol} <i>·</i> {stock.sector}</span></div><button className={`watch-button ${watched ? 'watched' : ''}`} aria-label={`${watched ? 'Remove' : 'Add'} ${stock.symbol} ${watched ? 'from' : 'to'} watchlist`} disabled={busy || locked} onClick={() => void toggleWatch(stock.symbol)}><Icon name="star" size={19} /></button></header><div className="stock-main-price"><strong>{money(stock.priceCents)}</strong><span className={stock.changePct >= 0 ? 'positive' : 'negative'}>{signedMoney(stock.changeCents)} ({percent(stock.changePct)})<small>24h change</small></span>{!stock.active && <span className="delisted-badge">Sell only</span>}</div>
            <div className="chart-controls"><div>{['1H', '6H', '1D'].map(range => <button key={range} className={period === range ? 'selected' : ''} onClick={() => setPeriod(range)}>{range}</button>)}</div><div><button title="Line chart" aria-label="Line chart" className={chartStyle === 'line' ? 'selected' : ''} onClick={() => setChartStyle('line')}><Icon name="linechart" size={15} /></button><button title="Candlestick chart" aria-label="Candlestick chart" className={chartStyle === 'candles' ? 'selected' : ''} onClick={() => setChartStyle('candles')}><Icon name="candles" size={15} /></button></div></div>
            {chart?.symbol === stock.symbol && chart.period === period ? <PriceChart candles={chart.candles} symbol={stock.symbol} style={chartStyle} /> : chartError ? <div className="chart-empty"><p>{chartError}</p></div> : <div className="chart-empty"><span className="invest-spinner" />Loading price history</div>}
            <div className="stock-range"><span>24h low<strong>{money(stock.lowCents)}</strong></span><i><b style={{ left: `${Math.max(0, Math.min(100, (stock.priceCents - stock.lowCents) / (stock.highCents - stock.lowCents || 1) * 100))}%` }} /></i><span>24h high<strong>{money(stock.highCents)}</strong></span></div>
          </section><aside className="trade-ticket"><div className="ticket-heading"><strong>Trade {stock.symbol}</strong><span>Market order</span></div><div className="trade-sides"><button className={side === 'buy' ? 'selected' : ''} disabled={busy || !stock.active} onClick={() => { setSide('buy'); setReviewError(''); }}>Buy</button><button className={side === 'sell' ? 'selected sell' : ''} disabled={busy} onClick={() => { setSide('sell'); setReviewError(''); }}>Sell</button></div><label className="share-input"><span>Number of shares</span><div><input aria-label="Number of shares" inputMode="numeric" type="number" min="1" step="1" max={market.rules.maxOrderShares} value={quantity} onChange={event => { setQuantity(event.target.value); setReviewError(''); }} /><button disabled={busy} onClick={() => {
              const available = side === 'sell' ? position?.quantity || 0 : Math.floor(account!.cashCents / (stock.askCents * (1 + market.rules.feeBps / 10000) + market.rules.minFeeCents));
              const max = Math.min(available, market.rules.maxOrderShares, Math.floor(market.rules.maxOrderValueCents / quotedPrice));
              setQuantity(String(Math.max(0, max)));
            }}>Max</button></div></label><div className="ticket-lines"><span>{side === 'buy' ? 'Ask price' : 'Bid price'}<strong>{money(quotedPrice)}</strong></span><span>Estimated fee <small>{(market.rules.feeBps / 100).toFixed(2)}%</small><strong>{money(validQuantity ? estimatedFee : 0)}</strong></span><span className="ticket-total">{side === 'buy' ? 'Estimated cost' : 'Estimated proceeds'}<strong>{money(validQuantity ? Math.max(0, estimatedTotal) : 0)}</strong></span></div>
            <button className={`invest-primary review-button ${side === 'sell' ? 'sell-button' : ''}`} disabled={busy || locked || !validQuantity || cannotAfford || exceedsOrderLimit || (side === 'buy' && !stock.active)} onClick={() => void prepareOrder()}>{busy ? 'Please wait…' : `Review ${side} order`}<Icon name="right" size={15} /></button>
            {exceedsOrderLimit && <p className="ticket-warning">Maximum order value is {money(market.rules.maxOrderValueCents)}.</p>}{cannotAfford && validQuantity && <p className="ticket-warning">{side === 'buy' ? 'Not enough buying power for this order.' : 'You do not own this many shares.'}</p>}{reviewError && !review && <p className="ticket-warning" role="alert">{reviewError}</p>}
            <div className="position-summary"><span>Your position<strong>{position?.quantity || 0} shares</strong></span><span>Market value<strong>{money(position?.valueCents || 0)}</strong></span>{position && <span>Unrealized P/L<strong className={position.pnlCents >= 0 ? 'positive' : 'negative'}>{signedMoney(position.pnlCents)}</strong></span>}</div><p className="order-note"><Icon name="shield" size={12} />Confirmed against a fresh server quote.</p>
          </aside></div>
          <div className="invest-section-title"><h3>{page === 'watchlist' ? 'On your radar' : 'Market snapshot'}</h3></div>
          <div className="stock-cards">{(page === 'watchlist' ? market.quotes.filter(q => account!.watchlist.includes(q.symbol)) : [...market.quotes].sort((a, b) => b.changePct - a.changePct)).slice(0, 4).map(q => <button key={q.symbol} className={selected === q.symbol ? 'selected' : ''} onClick={() => choose(q.symbol, page)}><div><Logo stock={q} small /><span><strong>{q.symbol}</strong><small>{q.name}</small></span><Icon name="right" size={12} /></div><div><strong>{money(q.priceCents)}</strong><span className={q.changePct >= 0 ? 'positive' : 'negative'}>{percent(q.changePct)}</span></div><Sparkline values={q.spark} positive={q.changePct >= 0} /></button>)}</div>
          {page === 'watchlist' && !account!.watchlist.length && <div className="watchlist-empty"><Icon name="star" size={20} /><span>Your watchlist is ready for its first stock. Use the star beside a company to add it.</span></div>}
          <div className="invest-section-title asset-section-title"><h3>{page === 'watchlist' ? 'Your saved stocks' : 'Explore investments'}</h3><span>{displayed.length} assets</span></div><div className="market-filters">{sectors.map(item => <button key={item} className={sector === item ? 'selected' : ''} onClick={() => setSector(item)}>{item}</button>)}</div><div className="invest-table stock-table"><div className="invest-table-head"><span>Asset</span><span>Price</span><span>24h change</span><span>24h trend</span><span>Watch</span></div>{displayed.map(q => <div className="invest-table-row" key={q.symbol}><button className="asset-cell" onClick={() => choose(q.symbol, page)}><Logo stock={q} small /><span><strong>{q.name}</strong><small>{q.symbol} · {q.sector}{!q.active ? ' · Sell only' : ''}</small></span></button><strong>{money(q.priceCents)}</strong><span className={q.changePct >= 0 ? 'positive' : 'negative'}>{percent(q.changePct)}</span><Sparkline values={q.spark} positive={q.changePct >= 0} /><button className={`watch-button ${account!.watchlist.includes(q.symbol) ? 'watched' : ''}`} disabled={busy || locked} aria-label={`Watch ${q.symbol}`} onClick={() => void toggleWatch(q.symbol)}><Icon name="star" size={16} /></button></div>)}</div><div className="company-summary"><Icon name="info" size={16} /><p><strong>About {stock.name}</strong>{stock.description}</p></div>
        </>}

        {page === 'portfolio' && <><div className="portfolio-breakdown"><section><div className="invest-section-title"><h3>Portfolio allocation</h3><span>{account!.positions.length} holdings</span></div><div className="allocation-bar">{account!.positions.map(p => <span key={p.symbol} title={`${p.symbol}: ${money(p.valueCents)}`} style={{ width: `${p.valueCents / (account!.equityCents || 1) * 100}%`, background: market.quotes.find(q => q.symbol === p.symbol)?.color }} />)}<span style={{ flex: 1, background: 'var(--invest-cash)' }} /></div><div className="allocation-legend">{account!.positions.map(p => <span key={p.symbol}><i style={{ background: market.quotes.find(q => q.symbol === p.symbol)?.color }} />{p.symbol}<strong>{(p.valueCents / (account!.equityCents || 1) * 100).toFixed(1)}%</strong></span>)}<span><i className="cash-dot" />Cash<strong>{(account!.cashCents / (account!.equityCents || 1) * 100).toFixed(1)}%</strong></span></div></section><section className="pnl-breakdown"><span>Realized profit / loss<strong className={account!.realizedPnlCents >= 0 ? 'positive' : 'negative'}>{signedMoney(account!.realizedPnlCents)}</strong></span><span>Unrealized profit / loss<strong className={account!.unrealizedPnlCents >= 0 ? 'positive' : 'negative'}>{signedMoney(account!.unrealizedPnlCents)}</strong></span><span>Total fees paid<strong>{money(account!.feesPaidCents)}</strong></span></section></div><div className="invest-section-title"><h3>Your investments</h3><span>Cost basis includes buy fees</span></div>{account!.positions.length ? <div className="invest-table holdings-table"><div className="invest-table-head"><span>Asset</span><span>Shares</span><span>Avg. cost</span><span>Value</span><span>Profit / loss</span><span /></div>{account!.positions.map(p => { const q = market.quotes.find(s => s.symbol === p.symbol)!; return <div className="invest-table-row" key={p.symbol}><button className="asset-cell" onClick={() => choose(p.symbol)}><Logo stock={q} small /><span><strong>{q.name}</strong><small>{p.symbol}</small></span></button><span>{p.quantity.toLocaleString()}</span><span>{money(p.averageCents)}</span><strong>{money(p.valueCents)}</strong><span className={p.pnlCents >= 0 ? 'positive' : 'negative'}>{signedMoney(p.pnlCents)}<small>{percent(p.costBasisCents ? p.pnlCents / p.costBasisCents * 100 : 0)}</small></span><button className="portfolio-trade" onClick={() => choose(p.symbol)}>Trade<Icon name="right" size={12} /></button></div>; })}</div> : <div className="invest-empty holdings-empty"><Icon name="portfolio" size={40} /><h2>Every portfolio starts somewhere.</h2><p>Explore the market, add funds and place your first order.</p><button className="invest-primary" onClick={() => setPage('markets')}>Explore markets</button></div>}</>}

        {page === 'activity' && <><div className="activity-filters">{[{id:'all',name:'All activity'},{id:'trades',name:'Trades'},{id:'transfers',name:'Transfers'}].map(f => <button key={f.id} className={activityFilter === f.id ? 'selected' : ''} onClick={() => setActivityFilter(f.id)}>{f.name}</button>)}<span>Most recent {market.account.history.length} records</span></div><div className="activity-list">{account!.history.filter(item => activityFilter === 'all' || (activityFilter === 'trades' ? ['buy', 'sell'].includes(item.type) : ['deposit', 'withdraw'].includes(item.type))).map(item => <div className="activity-row" key={item.id}><span className={`activity-icon ${item.type}`}><Icon name={item.type === 'buy' ? 'downleft' : item.type === 'sell' ? 'arrow' : 'transfer'} size={19} /></span><div><strong>{item.type === 'buy' ? 'Bought' : item.type === 'sell' ? 'Sold' : item.type === 'deposit' ? 'Funds added' : 'Withdrawal'} {item.symbol || ''}</strong><small>{item.symbol ? `${item.quantity} shares at ${money(item.priceCents || 0)}` : 'In-game bank transfer'} · {new Date(item.at).toLocaleString('en-GB', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}</small><span className="activity-id">{item.id}</span></div><div className="activity-amount"><strong className={['sell','deposit'].includes(item.type) ? 'positive' : ''}>{['sell','deposit'].includes(item.type) ? '+' : '−'}{money(item.amountCents)}</strong><small>{item.feeCents > 0 ? `${money(item.feeCents)} fee included` : 'No transfer fee'}</small></div><span className="filled-badge"><Icon name="check" size={12} />Completed</span></div>)}{!account!.history.length && <div className="invest-empty"><Icon name="history" size={32} /><h2>Your story starts here.</h2><p>Completed orders and transfers will appear here.</p></div>}</div></>}
        <footer className="invest-footer"><span><i className="live-dot" />Quotes updated {new Date(market.updatedAt).toLocaleTimeString('en-GB', { hour:'2-digit',minute:'2-digit',second:'2-digit' })}</span><span>Fictional market · {isPreview ? 'Preview balances' : account!.mode === 'paper' ? 'Practice funds' : 'In-game funds'} · No leverage</span></footer>
      </>}
    </div></div>
    {notice && <div className="invest-toast" role="status"><span><Icon name="check" size={17} /></span>{notice}<button aria-label="Dismiss investment notification" onClick={() => setNotice('')}><Icon name="close" size={14} /></button></div>}

    {review && <div className="invest-modal-overlay"><section className="invest-modal" role="dialog" aria-modal="true" aria-labelledby="order-heading"><button className="invest-modal-close" aria-label="Close order review" disabled={busy} onClick={() => { setReview(null); setReviewError(''); }}><Icon name="close" size={19} /></button><span className="modal-glyph"><Icon name="stocks" size={24} /></span><span className="invest-eyebrow">ONE LAST LOOK</span><h2 id="order-heading">Review your {review.side} order</h2><p>{review.name} <strong>{review.symbol}</strong></p><div className="order-review-lines"><span>Order type<strong>Market · {review.side === 'buy' ? 'Buy' : 'Sell'}</strong></span><span>Shares<strong>{review.quantity.toLocaleString()}</strong></span><span>Execution price<strong>{money(review.priceCents)}</strong></span><span>Trading fee<strong>{money(review.feeCents)}</strong></span><span className="review-total">{review.side === 'buy' ? 'You pay' : 'You receive'}<strong>{money(review.totalCents)}</strong></span></div><div className={`quote-timer ${expired ? 'expired' : ''}`}><Icon name="clock" size={14} />{expired ? 'Quote unavailable.' : `Quote valid for ${Math.max(0, Math.ceil((deadline - clock) / 1000))}s`}</div>{reviewError && <p className="modal-error" role="alert">{reviewError}</p>}<button className={`invest-primary ${review.side === 'sell' ? 'sell-button' : ''}`} disabled={busy || locked || expired || !!reviewError} onClick={() => void execute()}>{busy ? 'Processing…' : `Confirm ${review.side} · ${money(review.totalCents)}`}</button><small className="modal-footnote">Whole shares. No leverage. In-game funds only.</small></section></div>}
    {funds && market && <div className="invest-modal-overlay"><section className="invest-modal" role="dialog" aria-modal="true" aria-labelledby="funds-heading"><button className="invest-modal-close" aria-label="Close transfer" disabled={busy} onClick={() => setFunds(null)}><Icon name="close" size={19} /></button><span className="modal-glyph"><Icon name="wallet" size={25} /></span><span className="invest-eyebrow">KEEP YOUR NEXT MOVE READY</span><h2 id="funds-heading">{funds === 'deposit' ? 'Add funds' : 'Withdraw funds'}</h2><p>{funds === 'deposit' ? 'From your in-game bank to your brokerage.' : 'From your brokerage to your in-game bank.'}</p><div className="transfer-available"><span>{funds === 'deposit' ? 'Bank balance' : 'Available to withdraw'}</span><strong>{money(funds === 'deposit' ? market.account.bankBalanceCents || 0 : market.account.cashCents)}</strong></div><label className="transfer-input"><span>Amount in whole dollars</span><div><b>$</b><input aria-label="Transfer amount" disabled={busy} type="number" step="1" min={market.rules.minTransfer} max={market.rules.maxTransfer} value={amount} onChange={event => { setAmount(event.target.value); setFundsError(''); transferId.current = requestId(); }} /></div></label><div className="transfer-presets">{[500,1000,5000].map(value => <button key={value} disabled={busy} onClick={() => { setAmount(String(value)); transferId.current = requestId(); }}>{money(value * 100, 0)}</button>)}</div><div className="transfer-fee"><span>Transfer fee</span><strong>$0.00</strong></div>{fundsError && <p className="modal-error" role="alert">{fundsError}</p>}<button className="invest-primary" disabled={busy || locked || !Number.isInteger(Number(amount)) || Number(amount) < market.rules.minTransfer || Number(amount) > market.rules.maxTransfer} onClick={() => void transfer()}>{busy ? 'Processing…' : funds === 'deposit' ? `Confirm deposit · ${money(Number(amount) * 100)}` : `Confirm withdrawal · ${money(Number(amount) * 100)}`}</button><small className="modal-footnote">{isPreview ? 'Browser preview — no server money is moved.' : 'Transfers use your character’s in-game bank account.'}</small></section></div>}
    {receipt && <div className="invest-modal-overlay"><section className="invest-modal order-receipt" role="dialog" aria-modal="true" aria-labelledby="receipt-heading"><span className="receipt-check"><Icon name="check" size={29} /></span><span className="invest-eyebrow">YOUR NEXT CHAPTER</span><h2 id="receipt-heading">Order filled.</h2><p>You {receipt.type === 'buy' ? 'bought' : 'sold'} {receipt.quantity} shares of <strong>{receipt.symbol}</strong>.</p><div className="receipt-amount">{money(receipt.amountCents)}</div><span className="receipt-reference">{receipt.id}</span><div className="receipt-buttons"><button className="invest-secondary" onClick={() => setReceipt(null)}>Keep exploring</button><button className="invest-primary" onClick={() => { setReceipt(null); setPage('portfolio'); }}>View portfolio</button></div></section></div>}
  </div>;
}
