/* The dispatch map's ground: the same drawn island as my-hud's 3D minimap
 * (my-hud/html/map3d.js), seen from straight above with its buildings
 * standing up toward the top of the screen.
 *
 * The world it draws comes from the "GTA VI MiniMap (3D Buildings)" mod by
 * loneeps (Discord @moddims), used with their permission, by way of vice_hud
 * and my-hud (CC BY-NC-SA 4.0, see public/map3d/LICENSE). The shaders and the
 * world format are my-hud's; what changed is the camera. The minimap looks
 * down at a slant from behind the player, which bends the ground; Leaflet
 * draws every marker on a flat map, so here the ground stays flat (north up,
 * one metre the same size everywhere) and only height is slanted: a metre of
 * building is drawn `RISE` of a metre further up the screen. That keeps every
 * marker, zone and popup exactly where the flat map had it.
 */

export interface MapView {
	/** world point at the canvas centre */
	cx: number;
	cy: number;
	/** CSS pixels per metre across (x) and up (y) */
	sx: number;
	sy: number;
}

// Colours mirror my-hud's config.lua (Config.Map3D.paint / paintNight), the
// rest map3d.js's own defaults. `night` mixes between them, 0-1.
type Rgb = number[];
const PAINT: Record<string, Rgb | number> = {
	land: [214, 172, 174], road: [234, 202, 204], lot: [224, 188, 190],
	sand: [226, 196, 190], footprint: [200, 152, 156], rail: [192, 148, 152],
	lane: [176, 122, 128, 0.3], water: [124, 120, 130], shallow: [150, 144, 154],
	roof: [198, 130, 136], wall: [170, 98, 106], shadow: 20 / 255,
};
const NIGHT: Record<string, Rgb | number> = {
	land: [20, 18, 20], road: [58, 42, 46], lot: [30, 26, 28],
	sand: [34, 28, 30], footprint: [28, 24, 26], rail: [44, 34, 36],
	lane: [150, 60, 70, 0.25], water: [10, 11, 14], shallow: [16, 17, 22],
	roof: [46, 32, 36], wall: [24, 16, 18], shadow: 34 / 255,
};

const RISE = 0.7;       // screen metres per metre of height
const LIFT_CAP = 300;   // metres: tall towers stop growing (a 280 m tower is drawn ~145)
const SHADOW_MAX = 20;  // metres of shadow offset, at most

const PLACE = `
uniform vec2 uCentre; uniform vec2 uScale; uniform vec2 uPanel; uniform float uRise; uniform float uDepth;
vec4 place(vec2 p, float height) {
    vec2 d = (p - uCentre) * uScale;
    float x = uPanel.x * 0.5 + d.x;
    float y = uPanel.y * 0.5 - d.y - uRise * height;
    // nearer the viewer (south of the screen, and higher up) is drawn over what is behind
    return vec4(2.0 * x / uPanel.x - 1.0, 1.0 - 2.0 * y / uPanel.y, (uRise * d.y - height) * uDepth, 1.0);
}`;

const SHADERS: Record<string, { vs: string; fs: string }> = {
	ground: {
		vs: "layout(location = 0) in vec2 aPos; void main() { gl_Position = vec4(aPos, 0.0, 1.0); }",
		fs: `
uniform vec2 uCentre; uniform vec2 uScale; uniform vec2 uPanel;
uniform sampler2D uGround; uniform vec2 uGroundAt; uniform vec2 uGroundSize;
uniform vec3 uLand; uniform vec3 uWater; uniform vec3 uShallow; uniform vec3 uSand;
out vec4 o;
float edge(float v) { float e = max(fwidth(v) * 0.7, 0.02); return smoothstep(0.5 - e, 0.5 + e, v); }
void main() {
    vec2 p = uCentre + (gl_FragCoord.xy - uPanel * 0.5) / uScale;
    vec2 uv = (p - uGroundAt) / uGroundSize;
    vec2 t = texture(uGround, uv).rg;
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) t = vec2(1.0, 0.0);
    vec3 c = mix(uLand, uSand, edge(t.g));
    c = mix(c, mix(uShallow, uWater, smoothstep(0.6, 0.985, t.r)), edge(t.r));
    o = vec4(c, 1.0);
}`,
	},
	flat: {
		vs: PLACE + "\nlayout(location = 0) in vec2 aPos; void main() { gl_Position = place(aPos, 0.0); }",
		fs: "uniform vec4 uColour; out vec4 o; void main() { o = uColour; }",
	},
	building: {
		vs: PLACE + `
layout(location = 0) in vec4 aVert;
uniform float uLiftCap; uniform vec3 uRoof; uniform vec3 uWall; out vec3 vColour;
void main() {
    float h = aVert.z / (1.0 + aVert.z / uLiftCap);
    gl_Position = place(aVert.xy, h * uScale.x);
    if (aVert.w > 8.0) { vColour = uRoof; }
    else {
        vec2 n = vec2(cos(aVert.w), sin(aVert.w));
        float lum = 0.72 + 0.3 * (0.5 + 0.5 * (-0.75 * n.x - 0.35 * n.y));
        vColour = uWall * lum * (aVert.z > 0.01 ? 1.0 : 0.95);
    }
}`,
		fs: "in vec3 vColour; out vec4 o; void main() { o = vec4(vColour, 1.0); }",
	},
	// A roof's shadow: the roof again, on the ground, pushed down and right.
	// Drawn at one depth so overlapping shadows darken the ground once.
	shadow: {
		vs: PLACE + `
layout(location = 0) in vec4 aVert; uniform float uLiftCap; uniform float uShadowMax;
void main() {
    float h = aVert.z / (1.0 + aVert.z / uLiftCap);
    float px = min(h * uRise, uShadowMax) * uScale.x;
    gl_Position = place(aVert.xy, 0.0);
    gl_Position.xy += vec2(0.55, -0.3) * px * 2.0 / uPanel;
    gl_Position.z = 0.0;
}`,
		fs: "uniform vec4 uColour; out vec4 o; void main() { o = uColour; }",
	},
};

interface World {
	bounds: number[];
	chunk: number;
	gw: number;
	gh: number;
	ground: { file: string; cell: number; x0: number; y0: number; w: number; h: number };
	layers: Record<string, { xy: any; tri: any; starts: any }>;
	buildings?: Record<string, any>;
	f32: (r: { at: number; n: number }) => Float32Array;
	u32: (r: { at: number; n: number }) => Uint32Array;
}

// The world is fetched once per page and kept: reopening the map tab only
// uploads it to a fresh GL context.
let assets: Promise<{ buf: ArrayBuffer; ground: HTMLImageElement }> | null = null;

function loadImage(src: string): Promise<HTMLImageElement> {
	return new Promise((ok, bad) => {
		const im = new Image();
		im.onload = () => ok(im);
		im.onerror = () => bad(new Error(src + " would not load"));
		im.src = src;
	});
}

function loadAssets(base: string) {
	if (!assets) {
		assets = fetch(base + "world.bin")
			.then((r) => {
				if (!r.ok) throw new Error("map3d/world.bin is missing");
				return r.arrayBuffer();
			})
			.then(async (buf) => ({ buf, ground: await loadImage(base + parseWorld(buf).ground.file) }));
		assets.catch(() => { assets = null; });
	}
	return assets;
}

function parseWorld(buf: ArrayBuffer): World {
	const dv = new DataView(buf);
	if (dv.getUint32(0, true) !== 0x314d4856) throw new Error("world.bin: not a map"); // "VHM1"
	const headLen = dv.getUint32(4, true);
	const head = JSON.parse(new TextDecoder().decode(new Uint8Array(buf, 8, headLen)));
	const base = 8 + headLen;
	head.f32 = (r: { at: number; n: number }) => new Float32Array(buf, base + r.at, r.n);
	head.u32 = (r: { at: number; n: number }) => new Uint32Array(buf, base + r.at, r.n);
	return head;
}

export interface Map3DEngine {
	ready: Promise<void>;
	draw(view: MapView): void;
	setNight(n: number): void;
	destroy(): void;
}

export function createMap3D(canvas: HTMLCanvasElement, base = "./map3d/"): Map3DEngine {
	const gl = canvas.getContext("webgl2", { alpha: false, antialias: true, depth: true, stencil: false });
	let night = 0;
	let destroyed = false;
	let world: World | null = null;
	let groundTex: WebGLTexture | null = null;
	let quad: WebGLVertexArrayObject | null = null;
	const progs: Record<string, { p: WebGLProgram; u: Record<string, WebGLUniformLocation | null> }> = {};
	const layers: Record<string, { vao: WebGLVertexArrayObject; starts: Uint32Array }> = {};
	let bld: Record<string, { vao: WebGLVertexArrayObject; starts: Uint32Array }> | null = null;

	function ink(name: string): Rgb | number {
		const d = PAINT[name], n = NIGHT[name];
		if (n == null || night <= 0) return d;
		if (typeof d === "number") return d + ((n as number) - d) * night;
		return d.map((v, i) => v + (((n as Rgb)[i] ?? v) - v) * night);
	}

	function compile(name: string) {
		const g = gl!;
		const src = SHADERS[name];
		const sh = (type: number, body: string) => {
			const s = g.createShader(type)!;
			g.shaderSource(s, "#version 300 es\nprecision highp float;\n" + body);
			g.compileShader(s);
			if (!g.getShaderParameter(s, g.COMPILE_STATUS)) throw new Error(name + ": " + g.getShaderInfoLog(s));
			return s;
		};
		const p = g.createProgram()!;
		g.attachShader(p, sh(g.VERTEX_SHADER, src.vs));
		g.attachShader(p, sh(g.FRAGMENT_SHADER, src.fs));
		g.linkProgram(p);
		if (!g.getProgramParameter(p, g.LINK_STATUS)) throw new Error(name + ": " + g.getProgramInfoLog(p));
		const u: Record<string, WebGLUniformLocation | null> = {};
		const n = g.getProgramParameter(p, g.ACTIVE_UNIFORMS);
		for (let i = 0; i < n; i++) {
			const info = g.getActiveUniform(p, i)!;
			u[info.name] = g.getUniformLocation(p, info.name);
		}
		return { p, u };
	}

	function upload(target: number, data: ArrayBufferView) {
		const b = gl!.createBuffer();
		gl!.bindBuffer(target, b);
		gl!.bufferData(target, data, gl!.STATIC_DRAW);
		return b;
	}

	function buildWorld(head: World) {
		const g = gl!;
		world = head;
		for (const name of Object.keys(head.layers)) {
			const L = head.layers[name];
			const vao = g.createVertexArray()!;
			g.bindVertexArray(vao);
			upload(g.ARRAY_BUFFER, head.f32(L.xy));
			g.enableVertexAttribArray(0);
			g.vertexAttribPointer(0, 2, g.FLOAT, false, 0, 0);
			upload(g.ELEMENT_ARRAY_BUFFER, head.u32(L.tri));
			layers[name] = { vao, starts: head.u32(L.starts) };
		}
		if (head.buildings) {
			const B = head.buildings;
			const verts = upload(g.ARRAY_BUFFER, head.f32(B.verts));
			bld = {};
			for (const part of ["roof", "wall"]) {
				const vao = g.createVertexArray()!;
				g.bindVertexArray(vao);
				g.bindBuffer(g.ARRAY_BUFFER, verts);
				g.enableVertexAttribArray(0);
				g.vertexAttribPointer(0, 4, g.FLOAT, false, 20, 0);
				upload(g.ELEMENT_ARRAY_BUFFER, head.u32(B[part]));
				bld[part] = { vao, starts: head.u32(B[part + "Starts"]) };
			}
		}
		g.bindVertexArray(null);
	}

	function texture(image: HTMLImageElement) {
		const g = gl!;
		const t = g.createTexture();
		g.bindTexture(g.TEXTURE_2D, t);
		g.pixelStorei(g.UNPACK_PREMULTIPLY_ALPHA_WEBGL, true);
		g.pixelStorei(g.UNPACK_FLIP_Y_WEBGL, false);
		g.texImage2D(g.TEXTURE_2D, 0, g.RGBA, g.RGBA, g.UNSIGNED_BYTE, image);
		g.texParameteri(g.TEXTURE_2D, g.TEXTURE_MIN_FILTER, g.LINEAR_MIPMAP_LINEAR);
		g.texParameteri(g.TEXTURE_2D, g.TEXTURE_MAG_FILTER, g.LINEAR);
		g.texParameteri(g.TEXTURE_2D, g.TEXTURE_WRAP_S, g.CLAMP_TO_EDGE);
		g.texParameteri(g.TEXTURE_2D, g.TEXTURE_WRAP_T, g.CLAMP_TO_EDGE);
		g.generateMipmap(g.TEXTURE_2D);
		return t;
	}

	const ready = (async () => {
		if (!gl) throw new Error("no WebGL2");
		for (const n of Object.keys(SHADERS)) progs[n] = compile(n);
		quad = gl.createVertexArray();
		gl.bindVertexArray(quad);
		upload(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]));
		gl.enableVertexAttribArray(0);
		gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
		gl.bindVertexArray(null);
		const a = await loadAssets(base);
		if (destroyed) throw new Error("destroyed");
		buildWorld(parseWorld(a.buf));
		groundTex = texture(a.ground);
	})();

	function drawChunks(mesh: { vao: WebGLVertexArrayObject; starts: Uint32Array }, R: { x0: number; x1: number; y0: number; y1: number }) {
		if (R.x1 < R.x0 || R.y1 < R.y0) return;
		const g = gl!, w = world!;
		g.bindVertexArray(mesh.vao);
		for (let cy = R.y0; cy <= R.y1; cy++) {
			const from = mesh.starts[cy * w.gw + R.x0], to = mesh.starts[cy * w.gw + R.x1 + 1];
			if (to > from) g.drawElements(g.TRIANGLES, to - from, g.UNSIGNED_INT, from * 4);
		}
	}

	function draw(view: MapView) {
		if (!gl || !world || !groundTex || destroyed) return;
		const g = gl, w = world;
		const dpr = window.devicePixelRatio || 1;
		const W = Math.max(2, Math.round(canvas.clientWidth * dpr)), H = Math.max(2, Math.round(canvas.clientHeight * dpr));
		if (canvas.width !== W || canvas.height !== H) { canvas.width = W; canvas.height = H; }
		const sx = view.sx * dpr, sy = view.sy * dpr;

		// The squares that can be on screen: what lies inside it, plus whatever
		// south of it stands tall enough to reach up into it.
		const hx = W / 2 / sx, hy = H / 2 / sy, tall = LIFT_CAP * RISE, c = w.chunk, b = w.bounds;
		const R = {
			x0: Math.max(0, Math.floor((view.cx - hx - SHADOW_MAX - b[0]) / c)),
			x1: Math.min(w.gw - 1, Math.floor((view.cx + hx - b[0]) / c)),
			y0: Math.max(0, Math.floor((view.cy - hy - tall - b[1]) / c)),
			y1: Math.min(w.gh - 1, Math.floor((view.cy + hy + SHADOW_MAX - b[1]) / c)),
		};
		const depth = 1 / (RISE * (H + 2 * (tall + c) * sy) + LIFT_CAP * sx + 1000);

		const shared = (name: string) => {
			const pr = progs[name], u = pr.u;
			g.useProgram(pr.p);
			g.uniform2f(u.uCentre, view.cx, view.cy);
			g.uniform2f(u.uScale, sx, sy);
			g.uniform2f(u.uPanel, W, H);
			if (u.uRise) g.uniform1f(u.uRise, RISE);
			if (u.uDepth) g.uniform1f(u.uDepth, depth);
			if (u.uLiftCap) g.uniform1f(u.uLiftCap, LIFT_CAP);
			return u;
		};

		g.viewport(0, 0, W, H);
		g.disable(g.SCISSOR_TEST);
		g.depthMask(true);
		g.colorMask(true, true, true, true);
		g.clearColor(0, 0, 0, 1);
		g.clearDepth(1);
		g.clear(g.COLOR_BUFFER_BIT | g.DEPTH_BUFFER_BIT);
		g.disable(g.DEPTH_TEST);
		g.disable(g.BLEND);

		// The ground: land, with the survey's sand and sea over it.
		let u = shared("ground");
		g.activeTexture(g.TEXTURE0);
		g.bindTexture(g.TEXTURE_2D, groundTex);
		g.uniform1i(u.uGround, 0);
		g.uniform2f(u.uGroundAt, w.ground.x0, w.ground.y0);
		g.uniform2f(u.uGroundSize, w.ground.w * w.ground.cell, w.ground.h * w.ground.cell);
		const rgb = (name: string, uni: WebGLUniformLocation | null) => {
			const v = ink(name) as Rgb;
			g.uniform3f(uni, v[0] / 255, v[1] / 255, v[2] / 255);
		};
		rgb("land", u.uLand); rgb("water", u.uWater); rgb("shallow", u.uShallow); rgb("sand", u.uSand);
		g.bindVertexArray(quad);
		g.drawArrays(g.TRIANGLES, 0, 3);

		g.enable(g.BLEND);
		g.blendFunc(g.SRC_ALPHA, g.ONE_MINUS_SRC_ALPHA);

		u = shared("flat");
		for (const name of ["footprint", "rail", "road", "bridge", "lot", "lane"]) {
			if (!layers[name]) continue;
			const v = ink(name === "bridge" ? "road" : name) as Rgb;
			g.uniform4f(u.uColour, v[0] / 255, v[1] / 255, v[2] / 255, v.length > 3 ? v[3] : 1);
			drawChunks(layers[name], R);
		}

		if (bld) {
			u = shared("shadow");
			g.uniform1f(u.uShadowMax, SHADOW_MAX);
			g.uniform4f(u.uColour, 0, 0, 0, ink("shadow") as number);
			g.enable(g.DEPTH_TEST);
			g.depthFunc(g.LESS);
			drawChunks(bld.roof, R);
			g.clear(g.DEPTH_BUFFER_BIT);

			// Depth first, colour second: the nearest surface at a pixel is the one drawn.
			u = shared("building");
			rgb("roof", u.uRoof); rgb("wall", u.uWall);
			g.colorMask(false, false, false, false);
			drawChunks(bld.roof, R); drawChunks(bld.wall, R);
			g.colorMask(true, true, true, true);
			g.depthFunc(g.LEQUAL);
			g.depthMask(false);
			drawChunks(bld.roof, R); drawChunks(bld.wall, R);
			g.depthMask(true);
			g.disable(g.DEPTH_TEST);
		}
		g.bindVertexArray(null);
	}

	return {
		ready,
		draw,
		setNight(n: number) { night = Math.min(1, Math.max(0, n)); },
		destroy() {
			destroyed = true;
			gl?.getExtension("WEBGL_lose_context")?.loseContext();
		},
	};
}
