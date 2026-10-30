import type L from "leaflet";
import { createMap3D, type MapView } from "./engine";

type Gta = { x: number; y: number };

/* Draws the 3D island (engine.ts) under a Leaflet map and keeps it on
 * Leaflet's view: every pan, inertia glide and flyTo frame is a 'move', and
 * a wheel / button zoom is a CSS transition that Leaflet announces once with
 * 'zoomanim', so that one is played here alongside it.
 *
 * The map's CRS is linear (toMapLatLng is a scale and an offset), so the view
 * is fully described by where world (0, 0) lands and how many pixels a metre
 * is along each axis. */
export function attachMap3D(
	map: L.Map,
	toMapLatLng: (p: Gta) => [number, number],
	onReady: (ok: boolean) => void,
) {
	const container = map.getContainer();
	const canvas = document.createElement("canvas");
	canvas.className = "map3d-canvas";
	canvas.setAttribute("aria-hidden", "true");
	Object.assign(canvas.style, { position: "absolute", inset: "0", width: "100%", height: "100%", zIndex: "0", pointerEvents: "none" });
	container.insertBefore(canvas, container.firstChild);

	const engine = createMap3D(canvas);
	let loaded = false;
	let queued = 0;
	let anim: { from: Affine; to: Affine; start: number } | null = null;

	// Container px = o + world * s (y flipped by the CRS, so sy comes out negative).
	interface Affine { ox: number; oy: number; sx: number; sy: number }

	function affineAt(point: (ll: [number, number]) => L.Point): Affine {
		const o = point(toMapLatLng({ x: 0, y: 0 }));
		const ax = point(toMapLatLng({ x: 1000, y: 0 }));
		const ay = point(toMapLatLng({ x: 0, y: 1000 }));
		return { ox: o.x, oy: o.y, sx: (ax.x - o.x) / 1000, sy: (ay.y - o.y) / 1000 };
	}
	const current = () => affineAt((ll) => map.latLngToContainerPoint(ll));
	// Where Leaflet will have everything once it has zoomed to `zoom` about `center`.
	function target(center: L.LatLng, zoom: number): Affine {
		const half = map.getSize().divideBy(2), c = map.project(center, zoom);
		return affineAt((ll) => map.project(ll, zoom).subtract(c).add(half));
	}

	function viewOf(a: Affine): MapView {
		const w = container.clientWidth, h = container.clientHeight;
		return { cx: (w / 2 - a.ox) / a.sx, cy: (h / 2 - a.oy) / a.sy, sx: a.sx, sy: -a.sy };
	}

	// Leaflet's zoom transition: transform 0.25s cubic-bezier(0, 0, 0.25, 1).
	function ease(t: number) {
		let lo = 0, hi = 1, s = t;
		for (let i = 0; i < 20; i++) {
			s = (lo + hi) / 2;
			const x = 3 * (1 - s) * s * s * 0.25 + s * s * s;
			if (x < t) lo = s; else hi = s;
		}
		return 3 * (1 - s) * s * s + s * s * s;
	}

	function frame(now: number) {
		queued = 0;
		if (!loaded) return;
		if (anim) {
			const t = Math.min(1, (now - anim.start) / 250), k = ease(t), f = anim.from, to = anim.to;
			const lerp = (a: number, b: number) => a + (b - a) * k;
			engine.draw(viewOf({ ox: lerp(f.ox, to.ox), oy: lerp(f.oy, to.oy), sx: lerp(f.sx, to.sx), sy: lerp(f.sy, to.sy) }));
			if (t < 1) { queued = requestAnimationFrame(frame); return; }
			anim = null;
			return;
		}
		engine.draw(viewOf(current()));
	}
	function redraw() {
		if (!queued) queued = requestAnimationFrame(frame);
	}

	function onMove() { if (!anim) redraw(); }
	function onZoomAnim(e: L.ZoomAnimEvent) {
		anim = { from: current(), to: target(e.center, e.zoom), start: performance.now() };
		redraw();
	}
	function onZoomEnd() { anim = null; redraw(); }

	map.on("move zoom viewreset resize", onMove);
	map.on("zoomanim", onZoomAnim as L.LeafletEventHandlerFn);
	map.on("zoomend", onZoomEnd);
	const resize = new ResizeObserver(() => redraw());
	resize.observe(container);

	engine.ready.then(
		() => { loaded = true; redraw(); onReady(true); },
		() => { canvas.remove(); onReady(false); },
	);

	return {
		setNight(n: number) { engine.setNight(n); redraw(); },
		destroy() {
			map.off("move zoom viewreset resize", onMove);
			map.off("zoomanim", onZoomAnim as L.LeafletEventHandlerFn);
			map.off("zoomend", onZoomEnd);
			resize.disconnect();
			if (queued) cancelAnimationFrame(queued);
			engine.destroy();
			canvas.remove();
		},
	};
}
