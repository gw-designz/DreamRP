<script lang="ts">
	import { ico } from "@/icons";
	import { onMount } from "svelte";
	import { fetchNui } from "../utils/fetchNui";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { TIMING, APP_INFO } from "../constants";
	import NavigationPills from "./NavigationPills.svelte";
	import type { AuthService } from "../services/authService.svelte";
	import type { createTabService } from "../services/tabService.svelte";

	interface Props {
		authService: AuthService;
		tabService: ReturnType<typeof createTabService>;
		onOpacityStyleChange: (opacityStyle: string) => void;
	}

	let { authService, tabService, onOpacityStyleChange }: Props = $props();

	let info = $derived(APP_INFO[authService.jobType] || APP_INFO.leo);
	let player = $derived(authService.playerInfo());
	let showNav = $derived(authService.isAuthorized && !authService.isCivilian);

	let menuOpen = $state(false);
	let menuWrap: HTMLDivElement | undefined = $state();

	let opacityTimeout: ReturnType<typeof setTimeout> | null = $state(null);
	let documentOpacity = $state(1);

	const opacityStyle = $derived(`opacity: ${documentOpacity}`);

	$effect(() => {
		onOpacityStyleChange(opacityStyle);
	});

	// Hovering the department badge "peeks" through the MDT at the game world
	function handlePeekEnter() {
		if (opacityTimeout) {
			clearTimeout(opacityTimeout);
			opacityTimeout = null;
		}
		documentOpacity = 0.25;
	}

	function handlePeekLeave() {
		if (opacityTimeout) {
			clearTimeout(opacityTimeout);
		}

		opacityTimeout = setTimeout(() => {
			documentOpacity = 1;
			opacityTimeout = null;
		}, TIMING.topBarOpacityDelay);
	}

	function officerName(): string {
		const initial = player.firstName ? `${player.firstName.charAt(0)}.` : "";
		return `${player.rank} ${initial} ${player.lastName}`.replace(/\s+/g, " ").trim();
	}

	function openPreferences() {
		const inst = tabService.getActiveInstance();
		if (inst) tabService.setInstanceTab(inst.id, "Preferences");
	}

	function closeMdt() {
		fetchNui(NUI_EVENTS.NAVIGATION.CLOSE_UI);
	}

	onMount(() => {
		const onPointerDown = (e: PointerEvent) => {
			if (menuOpen && menuWrap && !menuWrap.contains(e.target as Node)) {
				menuOpen = false;
			}
		};
		window.addEventListener("pointerdown", onPointerDown);

		return () => {
			window.removeEventListener("pointerdown", onPointerDown);
			if (opacityTimeout) {
				clearTimeout(opacityTimeout);
			}
		};
	});
</script>

<header class="top-bar">
	<div
		class="brand"
		role="region"
		onmouseenter={handlePeekEnter}
		onmouseleave={handlePeekLeave}
	>
		<div class="brand-badge">
			<span class="material-icons">{@html ico(info.icon)}</span>
		</div>
		<div class="brand-text">
			<span class="brand-title">
				{authService.isAuthorized && player.department ? player.department : info.title}
			</span>
			<span class="brand-subtitle">{info.subtitle}</span>
		</div>
	</div>

	<div class="actions">
		{#if authService.isAuthorized}
			<span class="officer">
				{officerName()}
				{#if player.id}
					<span class="callsign">[<span class="callsign-num">{player.id}</span>]</span>
				{/if}
			</span>
		{/if}

		{#if showNav}
			<div class="menu-wrap" bind:this={menuWrap}>
				<button
					class="icon-btn"
					class:open={menuOpen}
					aria-label="Open navigation menu"
					aria-expanded={menuOpen}
					onclick={() => (menuOpen = !menuOpen)}
				>
					<span class="material-icons">{@html ico("menu")}</span>
				</button>
				{#if menuOpen}
					<div class="menu-pop">
						<NavigationPills
							{tabService}
							jobType={authService.jobType}
							{authService}
							onSelect={() => (menuOpen = false)}
						/>
					</div>
				{/if}
			</div>

			<span class="divider"></span>

			<button
				class="icon-btn"
				aria-label="Back"
				disabled={!tabService.canGoBack()}
				onclick={() => tabService.goBack()}
			>
				<span class="material-icons">{@html ico("arrow_back")}</span>
			</button>
			<button
				class="icon-btn"
				aria-label="Forward"
				disabled={!tabService.canGoForward()}
				onclick={() => tabService.goForward()}
			>
				<span class="material-icons">{@html ico("arrow_forward")}</span>
			</button>
			<button class="icon-btn" aria-label="Preferences" onclick={openPreferences}>
				<span class="material-icons">{@html ico("settings")}</span>
			</button>
		{/if}

		<button class="icon-btn" aria-label="Close MDT" onclick={closeMdt}>
			<span class="material-icons">{@html ico("close")}</span>
		</button>
	</div>
</header>

<style>
	.top-bar {
		min-height: 64px;
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 0 20px 0 24px;
		color: var(--primary-text);
		background: rgba(14, 14, 16, 0.98);
		border-bottom: 1px solid var(--border-primary);
		position: relative;
		z-index: 20;
		cursor: default;
	}

	.brand {
		display: flex;
		align-items: center;
		gap: 16px;
		min-width: 0;
	}

	/* my-hud status tile: dark chamfered plate, glowing accent icon, lit line along the bottom */
	.brand-badge {
		width: 44px;
		height: 44px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		background: linear-gradient(to top, rgba(var(--accent-rgb), 0.3), transparent 70%), rgba(8, 8, 10, 0.8);
		box-shadow: inset 0 -2px 0 var(--accent);
		clip-path: var(--chamfer);
	}

	.brand-badge .material-icons {
		font-size: 26px;
		color: var(--accent);
		filter: drop-shadow(0 0 8px rgba(var(--accent-rgb), 0.55));
	}

	.brand-text {
		display: flex;
		flex-direction: column;
		line-height: 1.25;
		min-width: 0;
	}

	.brand-title {
		font-family: var(--font-display);
		font-size: 22px;
		font-weight: 700;
		line-height: 1.05;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: #fff;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.brand-subtitle {
		font-size: 13px;
		font-weight: 500;
		color: var(--secondary-text);
	}

	.actions {
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.officer {
		font-size: 15px;
		font-weight: 600;
		color: #fff;
		margin-right: 10px;
		white-space: nowrap;
	}

	.callsign-num {
		color: var(--accent);
	}

	.menu-wrap {
		position: relative;
	}

	.menu-pop {
		position: absolute;
		top: calc(100% + 6px);
		right: 0;
		z-index: 50;
		animation: menu-in 0.12s ease-out;
	}

	.icon-btn {
		width: 36px;
		height: 36px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: transparent;
		border: none;
		color: #fff;
		cursor: pointer;
		position: relative;
		isolation: isolate;
	}

	/* Chamfered hover tile, matching the .sk-btn style */
	.icon-btn::before {
		content: "";
		position: absolute;
		inset: 0;
		clip-path: var(--chamfer);
		z-index: -1;
		transition: background 0.12s ease, box-shadow 0.12s ease;
	}

	.icon-btn .material-icons {
		font-size: 22px;
	}

	.icon-btn:hover:not(:disabled)::before {
		background: linear-gradient(to top, rgba(var(--accent-rgb), 0.18), transparent 60%), rgba(255, 255, 255, 0.055);
	}

	.icon-btn.open::before {
		background: linear-gradient(to top, rgba(var(--accent-rgb), 0.45), transparent), rgba(255, 255, 255, 0.055);
		box-shadow: inset 0 -2px 0 var(--accent);
	}

	.icon-btn:disabled {
		color: var(--disabled-text);
		cursor: default;
	}

	.divider {
		width: 1px;
		height: 24px;
		background: var(--border-primary);
		margin: 0 6px;
	}

	@keyframes menu-in {
		from {
			opacity: 0;
			transform: translateY(-4px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}
</style>
