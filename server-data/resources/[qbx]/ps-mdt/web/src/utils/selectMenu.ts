// Replaces the browser's native <select> popup (white, unstyleable in CEF)
// with an MDT-styled menu. The <select> stays the source of truth: picking an
// item sets select.value and fires input/change, so Svelte `bind:value` and
// `onchange` handlers keep working on every existing dropdown.

let menu: HTMLDivElement | null = null;
let activeSelect: HTMLSelectElement | null = null;
let items: { el: HTMLButtonElement; value: string; disabled: boolean }[] = [];
let highlighted = -1;

function isEnhanceable(el: EventTarget | null): el is HTMLSelectElement {
	return (
		el instanceof HTMLSelectElement &&
		!el.multiple &&
		el.size <= 1 &&
		!el.disabled &&
		!el.hasAttribute("data-native")
	);
}

function setHighlight(i: number) {
	if (highlighted >= 0 && items[highlighted]) items[highlighted].el.classList.remove("hl");
	highlighted = i;
	const it = items[i];
	if (it) {
		it.el.classList.add("hl");
		it.el.scrollIntoView({ block: "nearest" });
	}
}

function moveHighlight(delta: number) {
	if (!items.length) return;
	let i = highlighted;
	for (let n = 0; n < items.length; n++) {
		i = (i + delta + items.length) % items.length;
		if (!items[i].disabled) return setHighlight(i);
	}
}

function choose(value: string) {
	const sel = activeSelect;
	closeMenu();
	if (!sel || sel.value === value) return;
	sel.value = value;
	sel.dispatchEvent(new Event("input", { bubbles: true }));
	sel.dispatchEvent(new Event("change", { bubbles: true }));
}

function closeMenu() {
	menu?.remove();
	menu = null;
	activeSelect?.classList.remove("sk-native-open");
	activeSelect = null;
	items = [];
	highlighted = -1;
}

function addOption(opt: HTMLOptionElement, parent: HTMLElement) {
	if (opt.hidden) return;
	const btn = document.createElement("button");
	btn.type = "button";
	btn.className = "sk-menu-item";
	btn.textContent = opt.textContent?.trim() || opt.value;
	const disabled = opt.disabled;
	if (disabled) btn.classList.add("disabled");
	if (opt.selected) btn.classList.add("active");
	const index = items.length;
	btn.addEventListener("mousedown", (e) => e.preventDefault());
	btn.addEventListener("click", () => {
		if (!disabled) choose(opt.value);
	});
	btn.addEventListener("pointerenter", () => {
		if (!disabled) setHighlight(index);
	});
	items.push({ el: btn, value: opt.value, disabled });
	parent.appendChild(btn);
}

function openMenu(sel: HTMLSelectElement) {
	closeMenu();
	activeSelect = sel;
	sel.classList.add("sk-native-open");

	menu = document.createElement("div");
	menu.className = "sk-menu";
	menu.setAttribute("role", "listbox");

	for (const child of Array.from(sel.children)) {
		if (child instanceof HTMLOptGroupElement) {
			const head = document.createElement("div");
			head.className = "sk-menu-group";
			head.textContent = child.label;
			menu.appendChild(head);
			for (const o of Array.from(child.children)) {
				if (o instanceof HTMLOptionElement) addOption(o, menu);
			}
		} else if (child instanceof HTMLOptionElement) {
			addOption(child, menu);
		}
	}

	// The popup is attached to body, outside ContentArea's CSS zoom. Keep its
	// positioning in viewport pixels and scale only its visual dimensions.
	// Dividing fixed coordinates by zoom offsets the menu in Chromium/CEF.
	const rect = sel.getBoundingClientRect();
	const zoom = sel.offsetWidth ? rect.width / sel.offsetWidth : 1;
	menu.style.setProperty('--menu-scale', String(zoom));
	menu.style.minWidth = `${Math.min(rect.width, window.innerWidth - 16)}px`;
	menu.style.maxWidth = `${window.innerWidth - 16}px`;
	const above = Math.max(0, rect.top - 8);
	const below = Math.max(0, window.innerHeight - rect.bottom - 8);
	menu.style.maxHeight = `${Math.min(280 * zoom, Math.max(above, below))}px`;
	document.body.appendChild(menu);

	// Position under the select, flipping above when there isn't room
	const mh = menu.getBoundingClientRect().height;
	const top = below < mh + 8 && rect.top > below ? rect.top - mh - 4 : rect.bottom + 4;
	menu.style.left = `${Math.max(8, Math.min(rect.left, window.innerWidth - menu.getBoundingClientRect().width - 8))}px`;
	menu.style.top = `${Math.max(4, Math.min(top, window.innerHeight - mh - 4))}px`;

	const current = items.findIndex((it) => it.value === sel.value);
	if (current >= 0) setHighlight(current);
}

export function installSelectMenus(): () => void {
	const onMouseDown = (e: MouseEvent) => {
		if (menu && e.target instanceof Node && menu.contains(e.target)) return;
		if (e.button === 0 && isEnhanceable(e.target)) {
			e.preventDefault();
			const sel = e.target;
			sel.focus();
			if (activeSelect === sel) closeMenu();
			else openMenu(sel);
			return;
		}
		closeMenu();
	};

	const onKeyDown = (e: KeyboardEvent) => {
		if (menu) {
			if (e.key === "Escape") {
				e.preventDefault();
				e.stopPropagation();
				closeMenu();
			} else if (e.key === "ArrowDown") {
				e.preventDefault();
				moveHighlight(1);
			} else if (e.key === "ArrowUp") {
				e.preventDefault();
				moveHighlight(-1);
			} else if (e.key === "Enter" || e.key === " ") {
				e.preventDefault();
				const it = items[highlighted];
				if (it && !it.disabled) choose(it.value);
			} else if (e.key === "Tab") {
				closeMenu();
			}
			return;
		}
		// Keys that would open the native popup open ours instead
		if (isEnhanceable(e.target) && (e.key === " " || e.key === "Enter" || (e.altKey && e.key === "ArrowDown"))) {
			e.preventDefault();
			openMenu(e.target);
		}
	};

	const onScroll = (e: Event) => {
		if (menu && !(e.target instanceof Node && menu.contains(e.target))) closeMenu();
	};

	document.addEventListener("mousedown", onMouseDown, true);
	document.addEventListener("keydown", onKeyDown, true);
	window.addEventListener("scroll", onScroll, true);
	window.addEventListener("resize", closeMenu);
	window.addEventListener("blur", closeMenu);

	return () => {
		closeMenu();
		document.removeEventListener("mousedown", onMouseDown, true);
		document.removeEventListener("keydown", onKeyDown, true);
		window.removeEventListener("scroll", onScroll, true);
		window.removeEventListener("resize", closeMenu);
		window.removeEventListener("blur", closeMenu);
	};
}
