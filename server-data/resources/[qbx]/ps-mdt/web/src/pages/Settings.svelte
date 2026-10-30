<script lang="ts">
	import { ico } from "@/icons";
	import { onMount, onDestroy } from "svelte";
	import { DEPARTMENT_THEME, PERSONAL_THEMES, findPersonalTheme } from "@/constants/themes";
	import { settingsService } from "@/services/settingsService.svelte";

	const STORAGE_KEY = "ps-mdt-preferences";

	// Appearance
	let theme = $state(DEPARTMENT_THEME);

	// Clicking a swatch shows the theme straight away; Save keeps it.
	function pickTheme(id: string) {
		theme = id;
		settingsService.setPersonalTheme(id);
	}
	// Leaving without saving puts the saved theme back.
	onDestroy(() => settingsService.restoreSavedTheme());
	let notificationSounds = $state(true);
	let uiZoom = $state(130);

	// Map
	let defaultZoom = $state(5);
	let showOfficers = $state(true);
	let showVehicles = $state(true);
	let showBodycams = $state(false);

	// Patrol
	let patrolZoneNotifications = $state(true);

	let saveStatus: string | null = $state(null);
	let saveTimeout: ReturnType<typeof setTimeout> | null = null;

	// Tracks whether current values differ from the last saved state, so the
	// topbar can show an "Unsaved changes" hint.
	let savedSnapshot = $state("");
	function snapshot(): string {
		return JSON.stringify({ theme, notificationSounds, uiZoom, defaultZoom, showOfficers, showVehicles, showBodycams, patrolZoneNotifications });
	}
	let isDirty = $derived(savedSnapshot !== "" && snapshot() !== savedSnapshot);

	onMount(() => {
		loadPreferences();
		savedSnapshot = snapshot();

		// Respond to Lua client asking for the patrol zone notification preference.
		// Fires on resource start so the client has the correct value immediately.
		function handleNuiMessage(event: MessageEvent) {
			if (event.data?.type === "requestPatrolZonePref") {
				const saved = localStorage.getItem(STORAGE_KEY);
				let enabled = true; // default
				try {
					if (saved) {
						const data = JSON.parse(saved);
						if (data.patrolZoneNotifications !== undefined) {
							enabled = data.patrolZoneNotifications;
						}
					}
				} catch { /* ignore */ }
				// Send back to Lua via NUI callback
				fetch(`https://${(window as any).GetParentResourceName?.() ?? "ps-mdt"}/patrolZonePref`, {
					method: "POST",
					headers: { "Content-Type": "application/json" },
					body: JSON.stringify({ enabled }),
				}).catch(() => {});
			}
		}

		window.addEventListener("message", handleNuiMessage);
		return () => window.removeEventListener("message", handleNuiMessage);
	});

	function loadPreferences() {
		try {
			const saved = localStorage.getItem(STORAGE_KEY);
			if (!saved) return;
			const data = JSON.parse(saved);
			theme = findPersonalTheme(data.theme) ? data.theme : DEPARTMENT_THEME;
			if (data.notificationSounds !== undefined) notificationSounds = data.notificationSounds;
			if (data.uiZoom !== undefined) uiZoom = data.uiZoom;
			if (data.defaultZoom !== undefined) defaultZoom = data.defaultZoom;
			if (data.showOfficers !== undefined) showOfficers = data.showOfficers;
			if (data.showVehicles !== undefined) showVehicles = data.showVehicles;
			if (data.showBodycams !== undefined) showBodycams = data.showBodycams;
			if (data.patrolZoneNotifications !== undefined) patrolZoneNotifications = data.patrolZoneNotifications;
		} catch {
			// Ignore parse errors
		}
	}

	function savePreferences() {
		try {
			const data = {
				theme,
				notificationSounds,
				uiZoom,
				defaultZoom,
				showOfficers,
				showVehicles,
				showBodycams,
				patrolZoneNotifications,
			};
			localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
			savedSnapshot = snapshot();

			// Immediately sync patrol zone pref to Lua client
			fetch(`https://${(window as any).GetParentResourceName?.() ?? "ps-mdt"}/patrolZonePref`, {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify({ enabled: patrolZoneNotifications }),
			}).catch(() => {});

			showSaveStatus("Preferences saved");
		} catch {
			showSaveStatus("Failed to save");
		}
	}

	function showSaveStatus(message: string) {
		saveStatus = message;
		if (saveTimeout) clearTimeout(saveTimeout);
		saveTimeout = setTimeout(() => {
			saveStatus = null;
		}, 2500);
	}

	function applyZoom(value: number) {
		uiZoom = value;
		const el = document.querySelector(".content-area") as HTMLElement;
		if (el) {
			el.style.zoom = `${value}%`;
		}
	}

	function resetZoom() {
		applyZoom(130);
	}
</script>

<div class="settings-page">
	<div class="topbar">
		<span class="page-title">Settings</span>
		<span class="topbar-hint">Preferences are saved locally on this device</span>
		<div class="topbar-right">
			{#if saveStatus}
				<span class="save-status">{saveStatus}</span>
			{:else if isDirty}
				<span class="dirty-hint">Unsaved changes</span>
			{/if}
			<button class="btn-save" class:dirty={isDirty} onclick={savePreferences}>
				<span class="material-icons btn-save-icon">{@html ico("save")}</span>
				Save Preferences
			</button>
		</div>
	</div>

	<div class="settings-scroll">
		<div class="settings-grid">
			<div class="settings-card">
				<div class="card-head">
					<span class="material-icons card-icon">{@html ico("palette")}</span>
					<span class="card-label">Appearance</span>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Theme</span>
						<span class="setting-desc">Your own accent color. Department uses the colors set in Management</span>
					</div>
				</div>
				<div class="theme-swatches" role="radiogroup" aria-label="Theme">
					<button
						type="button"
						class="theme-swatch theme-swatch--dept"
						class:on={theme === DEPARTMENT_THEME}
						role="radio"
						aria-checked={theme === DEPARTMENT_THEME}
						title="Department"
						onclick={() => pickTheme(DEPARTMENT_THEME)}
					>
						<span class="swatch-chip"></span>
						<span class="swatch-name">Department</span>
					</button>
					{#each PERSONAL_THEMES as t (t.id)}
						<button
							type="button"
							class="theme-swatch"
							class:on={theme === t.id}
							role="radio"
							aria-checked={theme === t.id}
							title={t.name}
							style="--sw: {t.accent}"
							onclick={() => pickTheme(t.id)}
						>
							<span class="swatch-chip"></span>
							<span class="swatch-name">{t.name}</span>
						</button>
					{/each}
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Notification Sounds</span>
						<span class="setting-desc">Play sounds for dispatch alerts and messages</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={notificationSounds} />
						<span class="toggle-slider"></span>
					</label>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">UI Zoom</span>
						<span class="setting-desc">Adjust the overall MDT interface size</span>
					</div>
					<div class="zoom-control">
						<input
							type="range"
							class="zoom-slider"
							min="100"
							max="200"
							step="5"
							value={uiZoom}
							oninput={(e) => applyZoom(parseInt(e.currentTarget.value))}
						/>
						<span class="zoom-value">{uiZoom}%</span>
						{#if uiZoom !== 130}
							<button class="zoom-reset" onclick={resetZoom} type="button">Reset</button>
						{/if}
					</div>
				</div>
			</div>

			<div class="settings-card">
				<div class="card-head">
					<span class="material-icons card-icon">{@html ico("map")}</span>
					<span class="card-label">Map</span>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Default Zoom Level</span>
						<span class="setting-desc">Zoom level when opening the map (3-10)</span>
					</div>
					<input
						type="number"
						class="setting-input"
						min="3"
						max="10"
						bind:value={defaultZoom}
					/>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Show Officers</span>
						<span class="setting-desc">Display officer positions on the map</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={showOfficers} />
						<span class="toggle-slider"></span>
					</label>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Show Vehicles</span>
						<span class="setting-desc">Display tracked vehicles on the map</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={showVehicles} />
						<span class="toggle-slider"></span>
					</label>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Show Bodycams</span>
						<span class="setting-desc">Display bodycam feeds on the map</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={showBodycams} />
						<span class="toggle-slider"></span>
					</label>
				</div>
			</div>

			<div class="settings-card settings-card--full">
				<div class="card-head">
					<span class="material-icons card-icon">{@html ico("route")}</span>
					<span class="card-label">Patrol</span>
				</div>
				<div class="setting-row">
					<div class="setting-info">
						<span class="setting-label">Zone Notifications</span>
						<span class="setting-desc">Notify when you enter or leave your assigned patrol zone</span>
					</div>
					<label class="toggle">
						<input type="checkbox" bind:checked={patrolZoneNotifications} />
						<span class="toggle-slider"></span>
					</label>
				</div>
			</div>
		</div>
	</div>
</div>

<style>
	.settings-page {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		overflow: hidden;
	}

	/* ===== Topbar (same pattern as every other tab) ===== */
	.topbar {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 0 16px;
		height: 42px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}
	.page-title {
		font-size: 12px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}
	.topbar-hint {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.3);
	}
	.topbar-right {
		margin-left: auto;
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.save-status {
		font-size: 10px;
		color: rgba(110, 231, 183, 0.8);
		animation: fadeIn 0.2s ease-out;
	}
	.dirty-hint {
		font-size: 10px;
		color: rgba(234, 179, 8, 0.75);
		animation: fadeIn 0.2s ease-out;
	}

	.btn-save {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}
	.btn-save:hover {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}
	.btn-save.dirty {
		background: rgba(var(--accent-rgb), 0.14);
		border-color: rgba(var(--accent-rgb), 0.25);
		color: rgba(var(--accent-text-rgb), 0.95);
	}
	.btn-save-icon { font-size: 13px; }

	/* ===== Scroll area + card grid ===== */
	.settings-scroll {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		padding: 14px 16px;
	}
	.settings-scroll::-webkit-scrollbar { width: 4px; }
	.settings-scroll::-webkit-scrollbar-track { background: transparent; }
	.settings-scroll::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.06); border-radius: 2px; }

	.settings-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 12px;
		align-items: start;
	}

	.settings-card {
		background: rgba(255, 255, 255, 0.02);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 6px;
		padding: 12px 14px;
	}
	.settings-card--full { grid-column: 1 / -1; }

	.card-head {
		display: flex;
		align-items: center;
		gap: 6px;
		padding-bottom: 8px;
		margin-bottom: 4px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}
	.card-icon {
		font-size: 14px;
		color: rgba(var(--accent-text-rgb), 0.55);
	}
	.card-label {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.35);
	}

	/* ===== Rows ===== */
	.setting-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		padding: 8px 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
	}
	.setting-row:last-child { border-bottom: none; padding-bottom: 2px; }

	.setting-info { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
	.setting-label { color: rgba(255, 255, 255, 0.8); font-size: 11px; font-weight: 500; }
	.setting-desc  { color: rgba(255, 255, 255, 0.35); font-size: 10px; }

	/* ===== Controls ===== */

	/* Theme picker: chamfered tiles like the rest of the UI, lit along the bottom when chosen */
	.theme-swatches { display: grid; grid-template-columns: repeat(auto-fill, minmax(78px, 1fr)); gap: 6px; padding: 2px 0 10px; }
	.theme-swatch {
		--sw: 140, 144, 152;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 5px;
		padding: 8px 4px 6px;
		background: rgba(255, 255, 255, 0.04);
		border: none;
		clip-path: var(--chamfer);
		color: rgba(255, 255, 255, 0.7);
		cursor: pointer;
		transition: background 0.12s, box-shadow 0.12s, color 0.12s;
	}
	.theme-swatch:hover { background: rgba(var(--sw), 0.12); color: #fff; }
	.theme-swatch.on { background: linear-gradient(to top, rgba(var(--sw), 0.35), rgba(var(--sw), 0.05)); box-shadow: inset 0 -2px 0 rgb(var(--sw)); color: #fff; }
	.swatch-chip { width: 22px; height: 22px; clip-path: var(--chamfer-sm); background: rgb(var(--sw)); box-shadow: 0 0 10px rgba(var(--sw), 0.6); }
	.theme-swatch--dept .swatch-chip { background: conic-gradient(rgb(255, 36, 58), rgb(59, 130, 246), rgb(34, 197, 94), rgb(255, 64, 160), rgb(255, 36, 58)); box-shadow: none; }
	.swatch-name { font-size: 10px; font-weight: 600; line-height: 1; }

	.setting-input {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.75);
		padding: 4px 8px;
		border-radius: 3px;
		font-size: 10px;
		width: 48px;
		text-align: center;
		outline: none;
		transition: border-color 0.1s;
	}
	.setting-input:hover, .setting-input:focus { border-color: rgba(255, 255, 255, 0.12); }
	.setting-input::-webkit-outer-spin-button,
	.setting-input::-webkit-inner-spin-button { -webkit-appearance: none; margin: 0; }

	.zoom-control { display: flex; align-items: center; gap: 8px; }
	.zoom-slider {
		-webkit-appearance: none;
		appearance: none;
		width: 100px;
		height: 4px;
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
		outline: none;
		cursor: pointer;
	}
	.zoom-slider::-webkit-slider-thumb {
		-webkit-appearance: none;
		appearance: none;
		width: 12px;
		height: 12px;
		border-radius: 50%;
		background: rgba(var(--accent-text-rgb), 0.7);
		box-shadow: 0 0 0 3px rgba(var(--accent-rgb), 0.08);
		cursor: pointer;
		transition: background 0.1s, box-shadow 0.1s;
	}
	.zoom-slider::-webkit-slider-thumb:hover {
		background: rgba(var(--accent-text-rgb), 0.9);
		box-shadow: 0 0 0 4px rgba(var(--accent-rgb), 0.14);
	}
	.zoom-value {
		font-size: 10px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.6);
		min-width: 32px;
		text-align: center;
		font-variant-numeric: tabular-nums;
	}
	.zoom-reset {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}
	.zoom-reset:hover { background: rgba(255, 255, 255, 0.04); color: rgba(255, 255, 255, 0.6); }

	/* ===== Toggle ===== */
	.toggle {
		position: relative;
		display: inline-block;
		width: 32px;
		height: 18px;
		flex-shrink: 0;
	}
	.toggle input { opacity: 0; width: 0; height: 0; }
	.toggle-slider {
		position: absolute;
		cursor: pointer;
		top: 0; left: 0; right: 0; bottom: 0;
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 18px;
		transition: background 0.2s ease, border-color 0.2s ease;
	}
	.toggle-slider:hover { border-color: rgba(255, 255, 255, 0.12); }
	.toggle-slider::before {
		content: "";
		position: absolute;
		height: 12px;
		width: 12px;
		left: 2px;
		bottom: 2px;
		background: rgba(255, 255, 255, 0.4);
		border-radius: 50%;
		transition: transform 0.2s ease, background 0.2s ease;
	}
	.toggle input:checked + .toggle-slider {
		background: rgba(var(--accent-rgb), 0.35);
		border-color: rgba(var(--accent-rgb), 0.3);
	}
	.toggle input:checked + .toggle-slider::before {
		transform: translateX(14px);
		background: rgba(255, 255, 255, 0.85);
	}

	@keyframes fadeIn {
		0%   { opacity: 0; }
		100% { opacity: 1; }
	}

	@media (max-width: 900px) {
		.settings-grid { grid-template-columns: 1fr; }
		.settings-card--full { grid-column: 1; }
	}
</style>