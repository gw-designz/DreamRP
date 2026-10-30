// Generates src/icons/icons.generated.json: only the Solar icons the MDT maps to,
// so the full icon set never ships in the bundle and nothing is fetched at runtime.
// Run after editing src/icons/icon-map.json:  npm run icons
import { readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { getIconData, iconToSVG } from "@iconify/utils";

const require = createRequire(import.meta.url);
const solar = require("@iconify-json/solar/icons.json");
const map = JSON.parse(readFileSync(new URL("../src/icons/icon-map.json", import.meta.url), "utf8"));

const out = {};
for (const [name, solarName] of Object.entries(map)) {
	const data = getIconData(solar, solarName);
	if (!data) throw new Error(`Solar icon not found: ${solarName} (for "${name}")`);
	const svg = iconToSVG(data);
	out[name] = { body: svg.body, viewBox: svg.attributes.viewBox };
}

writeFileSync(new URL("../src/icons/icons.generated.json", import.meta.url), JSON.stringify(out));
console.log(`Wrote ${Object.keys(out).length} icons`);
