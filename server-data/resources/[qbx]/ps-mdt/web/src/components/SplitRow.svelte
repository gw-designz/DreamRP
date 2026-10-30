<script lang="ts">
	import { ico } from "@/icons";
	import type { Snippet } from "svelte";

	// One entry in a SplitView result list: round avatar, bold title, subtitle.
	interface Props {
		title: string;
		subtitle?: string;
		image?: string | null;
		icon?: string;
		active?: boolean;
		onclick?: () => void;
		/** Pills/badges on the right edge */
		trailing?: Snippet;
	}

	let { title, subtitle = "", image = null, icon = "person", active = false, onclick, trailing }: Props = $props();

	let broken = $state(false);
	$effect(() => {
		image;
		broken = false;
	});
</script>

<button class="split-row" class:active {onclick}>
	<div class="split-row-avatar">
		{#if image && !broken}
			<img src={image} alt="" onerror={() => (broken = true)} />
		{:else}
			<span class="material-icons">{@html ico(icon)}</span>
		{/if}
	</div>
	<div class="split-row-info">
		<span class="split-row-title">{title}</span>
		{#if subtitle}<span class="split-row-sub">{subtitle}</span>{/if}
	</div>
	{#if trailing}
		<div class="split-row-trailing">{@render trailing()}</div>
	{/if}
</button>

<style>
	.split-row { display: flex; align-items: center; gap: 14px; width: 100%; padding: 12px 14px; background: transparent; border: none; border-bottom: 1px solid var(--border-primary); border-left: 3px solid transparent; color: inherit; font: inherit; text-align: left; cursor: pointer; transition: background 0.1s; flex-shrink: 0; }
	.split-row:hover { background: var(--hover-bg); }
	.split-row.active { background: rgba(var(--accent-rgb), 0.16); border-left-color: rgb(var(--accent-rgb)); }
	.split-row-avatar { width: 44px; height: 44px; border-radius: 50%; background: rgba(255,255,255,0.04); display: flex; align-items: center; justify-content: center; overflow: hidden; flex-shrink: 0; }
	.split-row-avatar img { width: 100%; height: 100%; object-fit: cover; }
	.split-row-avatar .material-icons { font-size: 26px; color: #fff; }
	.split-row-info { display: flex; flex-direction: column; gap: 2px; flex: 1; min-width: 0; }
	.split-row-title { font-size: 16px; font-weight: 600; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.split-row-sub { font-size: 13px; font-weight: 500; color: var(--primary-text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.split-row-trailing { display: flex; align-items: center; gap: 4px; flex-shrink: 0; max-width: 40%; flex-wrap: wrap; justify-content: flex-end; }
</style>
