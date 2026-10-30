// This adapter runs only outside FiveM. Preview balances never reach a server.
import type { Account, Activity, Candle, MarketReply, MarketSnapshot, OrderQuote, Stock } from './types';
const KEY = 'nova-invest-preview-v2';
const definitions = [
  ['LFI','Lifeinvader','Technology','#ed4f61',18452], ['BNL','Bean Machine','Consumer','#bb844c',7238],
  ['VAP','Vapid Motor Co.','Automotive','#478bed',12684], ['MAZ','Maze Financial','Finance','#e34248',23876],
  ['ROR','RON Energy','Energy','#f39c39',9316], ['ECO','eCola','Consumer','#d74247',5892],
  ['FLY','FlyUS','Travel','#528bd7',4625], ['RWC','Redwood','Consumer','#b76f56',11240]
] as const;
type Store = { account: Account; quotes: Stock[]; candles: Record<string, Candle[]>; tick: number; revision: number; receipts: Record<string, string> };
let order: OrderQuote | null = null;
function value(store: Store) {
  let total = 0, cost = 0;
  store.account.positions.forEach(p => {
    p.valueCents = store.quotes.find(q => q.symbol === p.symbol)!.priceCents * p.quantity;
    p.pnlCents = p.valueCents - p.costBasisCents; p.averageCents = p.costBasisCents / p.quantity;
    total += p.valueCents; cost += p.costBasisCents;
  });
  store.account.investedCents = total; store.account.equityCents = store.account.cashCents + total; store.account.unrealizedPnlCents = total - cost;
}
function quoteFields(stock: Stock, bars: Candle[]) {
  const price = stock.priceCents, open = bars[0].o;
  Object.assign(stock, { bidCents: Math.floor(price * .9995), askCents: Math.ceil(price * 1.0005),
    changeCents: price - open, changePct: (price - open) / open * 100, openCents: open,
    highCents: Math.max(...bars.map(c => c.h)), lowCents: Math.min(...bars.map(c => c.l)),
    spark: [...bars.filter((_, i) => i % 50 === 0).map(c => c.c), price] });
}
function fresh(): Store {
  const time = Math.floor(Date.now() / 60000) * 60, candles: Store['candles'] = {};
  const quotes = definitions.map(([symbol,name,sector,color,price], index) => {
    const start = index % 3 === 0 ? .972 : index % 3 === 1 ? 1.023 : .986;
    let last = Math.round(price * start);
    const bars = Array.from({ length: 1440 }, (_, i) => {
      const wobble = Math.sin(i * .049 + index) * .004 + Math.sin(i * .173) * .002;
      const c = i === 1439 ? price : Math.round(price * (start + (1 - start) * i / 1439 + wobble));
      const bar = { t: time - (1439 - i) * 60, o: last, h: Math.max(last,c)+4, l: Math.min(last,c)-4, c }; last = c; return bar;
    });
    candles[symbol] = bars;
    const stock = { symbol,name,sector,color,priceCents:price,active:true,description:`${name} is a fictional ${sector.toLowerCase()} company on the Los Santos exchange.` } as Stock;
    quoteFields(stock,bars); return stock;
  });
  const openedAt = Date.now() - 86400000;
  const positions = [ ['LFI',30,535560], ['VAP',45,562050], ['MAZ',16,388800] ].map(([symbol,quantity,costBasisCents]) => ({symbol:String(symbol),quantity:Number(quantity),costBasisCents:Number(costBasisCents),openedAt,valueCents:0,pnlCents:0,averageCents:0}));
  const account: Account = { mode:'bank',revision:0,cashCents:2500000-positions.reduce((s,p)=>s+p.costBasisCents,0),positions,history:[],watchlist:['LFI','VAP','MAZ','ROR'],
    realizedPnlCents:0,unrealizedPnlCents:0,equityCents:0,investedCents:0,feesPaidCents:0,netDepositsCents:2500000,bankBalanceCents:7500000,createdAt:openedAt };
  let cash = 2500000;
  account.history = positions.map((p,i) => {
    cash -= p.costBasisCents;
    return {id:`preview_buy_${i}`,type:'buy',symbol:p.symbol,quantity:p.quantity,priceCents:Math.floor(p.costBasisCents/p.quantity),feeCents:0,amountCents:p.costBasisCents,at:openedAt+i*1000,cashAfterCents:cash} as Activity;
  }).reverse();
  const store = {account,quotes,candles,tick:Math.floor(Date.now()/30000),revision:1,receipts:{}}; value(store); return store;
}
function save(store: Store) { localStorage.setItem(KEY,JSON.stringify(store)); }
function load(): Store {
  let store: Store;
  try { store = JSON.parse(localStorage.getItem(KEY)||'null') || fresh(); } catch { store = fresh(); }
  const tick = Math.floor(Date.now()/30000);
  if (tick > store.tick) {
    store.quotes.forEach((stock,i) => {
      const old = stock.priceCents;
      stock.priceCents = Math.max(100,Math.round(old*(1+Math.sin(tick*.9+i*2)*.0011)));
      const bars = store.candles[stock.symbol], t = Math.floor(Date.now()/60000)*60, last = bars[bars.length-1];
      if(last.t===t) { last.c=stock.priceCents;last.h=Math.max(last.h,last.c);last.l=Math.min(last.l,last.c); }
      else bars.push({t,o:old,h:Math.max(old,stock.priceCents),l:Math.min(old,stock.priceCents),c:stock.priceCents});
      if(bars.length>1440) bars.shift(); quoteFields(stock,bars);
    }); store.tick=tick;store.revision++;
  }
  value(store);save(store);return store;
}
function snapshot(store: Store): MarketSnapshot {
  value(store);return {quotes:store.quotes,account:store.account,marketRevision:store.revision,updatedAt:store.tick*30000,serverTime:Date.now(),tickSeconds:30,
    rules:{feeBps:10,spreadBps:10,minFeeCents:1,maxOrderShares:10000,maxOrderValueCents:100000000,minTransfer:1,maxTransfer:500000}};
}
export function previewMarket(name: string,input: Record<string,unknown>): MarketReply {
  const store=load(),a=store.account, fail=(error:string):MarketReply=>({ok:false,error});
  const finish=(message:string,activity?:Omit<Activity,'at'|'cashAfterCents'>):MarketReply=>{
    a.revision++;store.receipts[String(input.requestId)]=message;
    if(activity)a.history.unshift({...activity,at:Date.now(),cashAfterCents:a.cashCents});
    a.history=a.history.slice(0,250);value(store);save(store);return{ok:true,market:snapshot(store),message};
  };
  if(name==='marketSnapshot')return{ok:true,market:snapshot(store)};
  if(name==='marketChart'){
    const periods:Record<string,number>={'1H':3600,'6H':21600,'1D':86400}, bars=store.candles[String(input.symbol)];
    if(!bars||!periods[String(input.period)])return fail('Chart is unavailable.');
    const chosen=bars.filter(c=>c.t>=Date.now()/1000-periods[String(input.period)]), step=Math.max(1,Math.ceil(chosen.length/100)), candles:Candle[]=[];
    for(let i=0;i<chosen.length;i+=step){const g=chosen.slice(i,i+step);candles.push({t:g[0].t,o:g[0].o,h:Math.max(...g.map(c=>c.h)),l:Math.min(...g.map(c=>c.l)),c:g.at(-1)!.c});}
    return{ok:true,chart:{symbol:String(input.symbol),period:String(input.period),candles,updatedAt:Date.now()}};
  }
  if(name==='marketQuote'){
    const stock=store.quotes.find(q=>q.symbol===input.symbol),qty=Number(input.quantity);
    if(!stock||!Number.isInteger(qty)||qty<1||qty>10000)return fail('Enter a valid whole number of shares.');
    if(input.side!=='buy'&&input.side!=='sell')return fail('Invalid order side.');
    const price=input.side==='buy'?stock.askCents:stock.bidCents,gross=price*qty,fee=Math.max(1,Math.round(gross*.001)),total=gross+(input.side==='buy'?fee:-fee);
    if(gross>100000000)return fail('Order exceeds the maximum trade value.');
    if(input.side==='buy'&&a.cashCents<total)return fail('Insufficient buying power. Add funds or reduce the quantity.');
    if(input.side==='sell'&&(a.positions.find(p=>p.symbol===stock.symbol)?.quantity||0)<qty)return fail('You do not own enough shares to sell.');
    order={token:crypto.randomUUID(),symbol:stock.symbol,name:stock.name,side:input.side,quantity:qty,priceCents:price,grossCents:gross,feeCents:fee,totalCents:total,expiresAt:Date.now()+10000,accountRevision:a.revision,marketRevision:store.revision};
    return{ok:true,quote:order,serverTime:Date.now()};
  }
  if(store.receipts[String(input.requestId)])return{ok:true,market:snapshot(store),message:store.receipts[String(input.requestId)],replayed:true};
  if(input.revision!==a.revision)return fail('Your account changed. Refresh and review the action again.');
  if(name==='marketWatch'){
    const symbol=String(input.symbol);a.watchlist=input.watched?[...new Set([...a.watchlist,symbol])]:a.watchlist.filter(s=>s!==symbol);
    return finish(input.watched?'Added to your watchlist.':'Removed from your watchlist.');
  }
  if(name==='marketTransfer'){
    const amount=Number(input.amount);
    if(!Number.isInteger(amount)||amount<1||amount>500000)return fail('Enter a whole-dollar amount between $1 and $500,000.');
    if(input.direction==='deposit'){
      if((a.bankBalanceCents||0)<amount*100)return fail('Your preview bank has insufficient funds.');
      a.bankBalanceCents!-=amount*100;a.cashCents+=amount*100;a.netDepositsCents+=amount*100;
    }else if(input.direction==='withdraw'){
      if(a.cashCents<amount*100)return fail('Not enough available brokerage cash.');
      a.bankBalanceCents!+=amount*100;a.cashCents-=amount*100;a.netDepositsCents-=amount*100;
    }else return fail('Invalid transfer direction.');
    return finish(input.direction==='deposit'?'Funds added to your brokerage account.':'Funds returned to your in-game bank.',{id:String(input.requestId),type:input.direction,feeCents:0,amountCents:amount*100});
  }
  if(name==='marketTrade'){
    if(!order||order.token!==input.token||order.expiresAt<=Date.now()||order.marketRevision!==store.revision||order.accountRevision!==a.revision)return fail('The market moved or the quote expired. Review a fresh quote.');
    const q=order;order=null;let p=a.positions.find(p=>p.symbol===q.symbol),realized=0;
    if(q.side==='buy'){
      if(a.cashCents<q.totalCents)return fail('Insufficient buying power.');
      if(!p){p={symbol:q.symbol,quantity:0,costBasisCents:0,valueCents:0,averageCents:0,pnlCents:0,openedAt:Date.now()};a.positions.push(p);}
      p.quantity+=q.quantity;p.costBasisCents+=q.totalCents;a.cashCents-=q.totalCents;
    }else{
      if(!p||p.quantity<q.quantity)return fail('Insufficient shares.');
      const cost=q.quantity===p.quantity?p.costBasisCents:Math.floor(p.costBasisCents*q.quantity/p.quantity);
      p.quantity-=q.quantity;p.costBasisCents-=cost;realized=q.totalCents-cost;a.realizedPnlCents+=realized;a.cashCents+=q.totalCents;a.positions=a.positions.filter(p=>p.quantity>0);
    }
    a.feesPaidCents+=q.feeCents;
    return finish(`${q.side==='buy'?'Bought':'Sold'} ${q.quantity} ${q.symbol} shares.`,{id:String(input.requestId),type:q.side,symbol:q.symbol,quantity:q.quantity,priceCents:q.priceCents,feeCents:q.feeCents,amountCents:q.totalCents,realizedPnlCents:realized});
  }
  return fail('Unsupported preview action.');
}
