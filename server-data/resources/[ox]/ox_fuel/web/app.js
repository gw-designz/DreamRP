const params = new URLSearchParams(location.search);
const MODE = params.get('mode') || 'idle';
const RES = params.get('res') || 'ox_fuel';

const $title = document.getElementById('title');
const $body = document.getElementById('body');
const $slots = document.getElementById('slots');
const $hint = document.getElementById('hint');
const $toast = document.getElementById('toast');

let cfg = { grades: [], payment: { cash: true, card: true }, presets: [10, 20], blocks: 11, maxLitres: 999, petrolCan: {} };
let ctx = null; // context from the game when the screen is opened
let isOpen = false;
let pageName = null;
let page = null;
let sel = { grade: null, input: '', litres: 0, full: false };
let session = null;
let completeTimer = null;
let animTimer = null;

const SLOTS = ['L1', 'L2', 'L3', 'L4', 'R1', 'R2', 'R3', 'R4'];
const GRADE_SLOTS = ['L1', 'L2', 'R1', 'R2', 'L3', 'R3'];
const GRADE_COLORS = { regular: '#3e9b4f', midgrade: '#d4a22a', premium: '#b8343e', diesel: '#3d4e9e' };

function post(name, data = {}) {
	return fetch(`https://${RES}/${name}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify(data),
	}).then((r) => r.json()).catch(() => null);
}

const money = (n) => '$' + Math.round(n).toLocaleString('en-US');
const ppl = (n) => '$' + Number(n).toFixed(2) + ' / L';
const litres = (n) => Number(n).toFixed(1);
const gradeById = (id) => cfg.grades.find((g) => g.id === id);
const cost = (l, g) => Math.ceil(l * g.price);

function toast(message) {
	$toast.textContent = message;
	$toast.classList.add('show');
	clearTimeout(toast.timer);
	toast.timer = setTimeout(() => $toast.classList.remove('show'), 2400);
}

function blocks(filled, next = false) {
	const n = cfg.blocks || 11;
	const width = `calc((100% - ${(n - 1) * 5}px) / ${n})`;
	let html = '';
	for (let i = 0; i < Math.min(filled, n); i++) html += `<i style="width:${width}"></i>`;
	if (next && filled < n) html += `<i class="next" style="width:${width}"></i>`;
	return `<div class="blocks" id="blocks">${html}</div>`;
}

/* Pages
 * Each page returns { title, hint, body, layout, keys, pad }
 * keys: soft key labels on the screen, lined up with the side buttons (L1-L4, R1-R4)
 * pad:  handler for the physical keypad
 */

const pages = {
	idle: () => ({
		title: 'WELCOME',
		hint: 'PAY AT THE PUMP WITH CASH OR CARD',
		body: `
			<div class="big">LIFT NOZZLE TO BEGIN</div>
			<div class="rows" style="width:420px">
				${cfg.grades.map((g) => `<div><span>${g.octane} · ${g.label}</span><span>${ppl(g.price)}</span></div>`).join('')}
			</div>`,
	}),

	busy: () => ({
		title: 'FUELING IN PROGRESS',
		hint: 'PUMP IN USE',
		body: `${blocks(0)}<div class="small">PLEASE WAIT</div>`,
		animate: true,
	}),

	noVehicle: () => ({
		title: 'INSERT NOZZLE',
		hint: 'LIFT THE NOZZLE AND PLACE IT IN YOUR VEHICLE',
		body: `<div class="big">NO VEHICLE DETECTED</div><div class="small">INSERT THE NOZZLE TO SELECT YOUR FUEL</div>`,
		keys: {
			L4: cfg.petrolCan.enabled && {
				label: `${ctx.petrolCanEquipped ? 'REFILL' : 'BUY'} JERRY CAN · ${money(ctx.petrolCanEquipped ? cfg.petrolCan.refillPrice : cfg.petrolCan.price)}`,
				action: () => post('petrolCan'),
			},
			R4: { label: 'EXIT', dark: true, action: () => post('exit') },
		},
		pad: { cancel: () => post('exit') },
	}),

	electric: () => ({
		title: 'ELECTRIC VEHICLE',
		hint: 'THIS VEHICLE DOES NOT TAKE FUEL',
		body: `<div class="big">NO FUEL REQUIRED</div>`,
		keys: { R4: { label: 'EXIT', dark: true, action: () => post('exit') } },
		pad: { cancel: () => post('exit') },
	}),

	full: () => ({
		title: 'TANK FULL',
		hint: 'PLEASE HANG UP NOZZLE',
		body: `
			<div class="big">YOUR TANK IS FULL</div>
			<div class="gauge" style="width:392px"><div style="width:100%"></div></div>
			<div class="small">${litres(ctx.vehicle.capacity)} / ${litres(ctx.vehicle.capacity)} L</div>`,
		keys: { R4: { label: 'EXIT', dark: true, action: () => post('exit') } },
		pad: { cancel: () => post('exit') },
	}),

	grade: () => {
		const v = ctx.vehicle;
		const keys = {
			L4: { label: 'EXIT', action: () => post('exit') },
		};

		cfg.grades.slice(0, GRADE_SLOTS.length).forEach((g, i) => {
			keys[GRADE_SLOTS[i]] = {
				label: g.label,
				swatch: GRADE_COLORS[g.id],
				price: ppl(g.price),
				action: () => {
					sel = { grade: g.id, input: '', litres: 0, full: false };
					show('amount');
				},
			};
		});

		if (cfg.petrolCan.enabled) {
			keys.R4 = {
				label: `${ctx.petrolCanEquipped ? 'REFILL' : 'BUY'} JERRY CAN`,
				action: () => post('petrolCan'),
			};
		}

		return {
			title: 'SELECT FUEL TYPE',
			hint: 'PRESS THE BUTTON NEXT TO YOUR FUEL',
			layout: 'center',
			body: `
				<div class="small">TANK</div>
				<div class="mid">${litres(v.litres)} L</div>
				<div class="gauge"><div style="width:${Math.min(100, v.fuel)}%"></div></div>
				<div class="small">OF ${litres(v.capacity)} L</div>`,
			keys,
			pad: { cancel: () => post('exit') },
		};
	},

	amount: () => {
		const g = gradeById(sel.grade);
		const ok = sel.litres >= 0.1;
		const keys = {
			L4: { label: 'BACK', action: () => show('grade') },
			R4: { label: 'CONTINUE', dark: ok, empty: !ok, action: () => ok && show('payment') },
		};

		cfg.presets.slice(0, 2).forEach((p, i) => {
			keys['R' + (i + 1)] = { label: `${p} L`, action: () => setLitres(String(p)) };
		});

		keys.R3 = { label: 'FULL', action: () => setLitres('', true) };

		return {
			title: `ENTER AMOUNT · ${g.label}`,
			hint: 'USE THE KEYPAD · PRESS ENTER TO CONTINUE',
			layout: 'left',
			body: `
				<div class="readout" id="litres-box">
					<div class="k">LITRES</div>
					<div class="v">${sel.full ? 'FULL · ' + litres(sel.litres) : (sel.input || '0')} L</div>
				</div>
				<div class="readout">
					<div class="k">ESTIMATED COST · ${ppl(g.price)}</div>
					<div class="v">${money(cost(sel.litres, g))}</div>
				</div>
				<div class="small" style="text-align:left">TANK SPACE ${litres(ctx.vehicle.missing)} L</div>`,
			keys,
			pad: {
				digit: (d) => {
					const input = sel.full ? '' : sel.input;
					if (input.length < String(cfg.maxLitres).length) setLitres(input + d);
				},
				back: () => setLitres((sel.full ? '' : sel.input).slice(0, -1)),
				clear: () => setLitres(''),
				plus: () => setLitres(String(Math.floor(sel.litres) + 1)),
				minus: () => setLitres(String(Math.max(0, Math.ceil(sel.litres) - 1))),
				enter: () => ok && show('payment'),
				cancel: () => show('grade'),
			},
		};
	},

	payment: () => {
		const g = gradeById(sel.grade);
		const pay = (method) => () => startPayment(method);
		return {
			title: 'SELECT PAYMENT',
			hint: `CASH IN POCKET ${money(ctx.cash || 0)}`,
			layout: 'left',
			body: `
				<div class="rows">
					<div><span>FUEL</span><span>${g.label}</span></div>
					<div><span>LITRES</span><span>${litres(sel.litres)} L</span></div>
					<div><span>PRICE</span><span>${ppl(g.price)}</span></div>
					<div><span>TOTAL</span><span>${money(cost(sel.litres, g))}</span></div>
				</div>
				<div class="small" style="text-align:left">UNUSED FUEL IS REFUNDED</div>`,
			keys: {
				R1: cfg.payment.cash && { label: 'CASH', action: pay('cash') },
				R2: cfg.payment.card && { label: 'CARD', action: pay('card') },
				L4: { label: 'BACK', action: () => show('amount') },
			},
			pad: { cancel: () => show('amount') },
		};
	},

	processing: () => ({
		title: 'AUTHORIZING',
		hint: 'DO NOT REMOVE NOZZLE',
		body: `${blocks(0)}<div class="small">PLEASE WAIT</div>`,
		animate: true,
	}),

	fueling: () => ({
		title: 'FUELING IN PROGRESS',
		hint: 'DO NOT REMOVE NOZZLE',
		body: `${blocks(0)}<div class="small" id="progress-text">0.0 / 0.0 L BEING ADDED</div>`,
		keys: {
			R4: { label: 'STOP FUELING', dark: true, action: () => post('stop') },
		},
		pad: { cancel: () => post('stop') },
	}),

	complete: () => {
		const r = sel.result || {};
		const titles = {
			complete: 'FUELING COMPLETE',
			full: 'TANK FULL',
			stopped: 'FUELING STOPPED',
			removed: 'NOZZLE REMOVED',
			snapped: 'HOSE DISCONNECTED',
			fire: 'EMERGENCY STOP',
		};
		const bad = r.reason === 'snapped' || r.reason === 'fire';
		return {
			title: titles[r.reason] || titles.complete,
			hint: bad ? 'PLEASE SEE CASHIER' : 'THANK YOU · PLEASE HANG UP NOZZLE',
			body: `
				<div class="rows" style="width:392px">
					<div><span>PUMPED</span><span>${litres(r.litres || 0)} L</span></div>
					<div><span>CHARGED</span><span>${money(r.cost || 0)}</span></div>
					<div><span>RETURNED</span><span class="${r.refund > 0 ? 'good' : ''}">${money(r.refund || 0)}</span></div>
				</div>`,
			keys: isOpen ? { R4: { label: 'DONE', dark: true, action: done } } : {},
			pad: { enter: done, cancel: done },
		};
	},
};

function renderSoft(slot, key) {
	const side = slot[0] === 'L' ? 'left' : 'right';
	const row = 'row' + slot[1];
	const arrow = `<div class="arrow">${key ? (side === 'left' ? '‹' : '›') : ''}</div>`;

	if (!key) return `<div class="soft ${side} ${row} empty">${side === 'left' ? arrow : ''}<div class="text"></div>${side === 'right' ? arrow : ''}</div>`;

	const classes = ['soft', side, row, key.dark ? 'dark' : '', key.empty ? 'empty' : ''].join(' ');
	const text = `<div class="text">${key.swatch ? `<span class="swatch" style="background:${key.swatch}"></span>` : ''}${key.label}${key.price ? `<span class="price">${key.price}</span>` : ''}</div>`;

	return `<div class="${classes}" data-slot="${slot}">${side === 'left' ? arrow + text : text + arrow}</div>`;
}

function show(name) {
	pageName = name;
	page = pages[name]();

	clearInterval(animTimer);

	$title.textContent = page.title || '';
	$hint.textContent = page.hint || '';
	$body.className = 'lcd-body' + ({ left: ' narrow', center: ' narrow-both' }[page.layout] || '');
	$body.innerHTML = page.body || '';

	const keys = page.keys || {};
	$slots.innerHTML = SLOTS.map((slot) => {
		const key = keys[slot];
		// the bottom row always shows its boxes, like the real pump
		if (!key && slot[1] !== '4') return '';
		return renderSoft(slot, key || null);
	}).join('');

	if (page.animate) {
		let i = 0;
		animTimer = setInterval(() => {
			i = (i + 1) % ((cfg.blocks || 11) + 1);
			const el = document.getElementById('blocks');
			if (el) el.outerHTML = blocks(i);
		}, 300);
	}

	if (name === 'fueling' && session) updateProgress(session);
}

/* Flow */

function startPage() {
	if (session) return 'fueling';
	if (!ctx || !ctx.vehicle || !ctx.vehicle.connected) return 'noVehicle';
	if (ctx.vehicle.electric) return 'electric';
	if (ctx.vehicle.missing < 0.1) return 'full';
	return 'grade';
}

function setLitres(value, full = false) {
	const max = Math.min(ctx.vehicle.missing, cfg.maxLitres);
	let over = false;

	if (full) {
		sel.input = '';
		sel.full = true;
		sel.litres = Math.floor(max * 100) / 100;
	} else {
		let l = Number(value) || 0;

		if (l > max) {
			l = Math.floor(max);
			value = String(l);
			over = true;
		}

		sel.full = false;
		sel.input = value === '0' ? '' : value;
		sel.litres = l;
	}

	show('amount');

	if (over) {
		document.getElementById('litres-box')?.classList.add('flash');
		toast('NOT ENOUGH TANK SPACE');
	}
}

async function startPayment(method) {
	show('processing');

	const [res] = await Promise.all([
		post('pay', { grade: sel.grade, litres: sel.litres, method }),
		new Promise((r) => setTimeout(r, 1200)),
	]);

	if (res && res.ok) {
		session = res.session;
		show('fueling');
	} else {
		show('payment');
		toast(res?.error || 'TRANSACTION DECLINED');
	}
}

async function done() {
	clearTimeout(completeTimer);

	if (!isOpen) return show('idle');

	const fresh = await post('refresh');
	if (fresh) ctx = fresh;
	show(startPage());
}

function updateProgress(s) {
	const n = cfg.blocks || 11;
	const pct = s.target > 0 ? s.dispensed / s.target : 0;
	const el = document.getElementById('blocks');
	const text = document.getElementById('progress-text');

	if (el) el.outerHTML = blocks(Math.floor(pct * n), pct < 1);
	if (text) text.textContent = `${litres(s.dispensed)} / ${litres(s.target)} L BEING ADDED`;
}

/* Input */

function press(el) {
	el.classList.add('pressed');
	setTimeout(() => el.classList.remove('pressed'), 120);
}

document.addEventListener('click', (e) => {
	const slotEl = e.target.closest('[data-slot]');

	if (slotEl) {
		const key = page?.keys?.[slotEl.dataset.slot];
		if (slotEl.tagName === 'BUTTON') press(slotEl);
		if (key && !key.empty && key.action) key.action();
		return;
	}

	const padEl = e.target.closest('[data-pad]');

	if (padEl) {
		press(padEl);
		const k = padEl.dataset.pad;
		const pad = page?.pad || {};
		if (/^\d$/.test(k)) pad.digit?.(k);
		else pad[k]?.();
	}
});

/* Messages from the game */

const handlers = {
	init(data) {
		Object.assign(cfg, data);
		if (MODE === 'busy') show('busy');
		else if (!isOpen && !session && pageName !== 'complete') show('idle');
	},

	open(data) {
		ctx = data;
		isOpen = true;
		session = data.session || null;
		clearTimeout(completeTimer);
		show(startPage());
	},

	close() {
		isOpen = false;
		if (session) show('fueling');
		else if (pageName === 'complete') show('complete');
		else show('idle');
	},

	progress(data) {
		session = data;
		if (pageName !== 'fueling') show('fueling');
		else updateProgress(data);
	},

	complete(data) {
		session = null;
		sel.result = data;
		show('complete');
		clearTimeout(completeTimer);
		completeTimer = setTimeout(() => {
			if (pageName === 'complete') done();
		}, 10000);
	},
};

window.addEventListener('message', (e) => {
	let msg = e.data;
	if (typeof msg === 'string') {
		try { msg = JSON.parse(msg); } catch { return; }
	}
	const fn = msg && handlers[msg.action];
	if (fn) fn(msg.data);
});

show(MODE === 'busy' ? 'busy' : 'idle');
post('ready', { mode: MODE });
