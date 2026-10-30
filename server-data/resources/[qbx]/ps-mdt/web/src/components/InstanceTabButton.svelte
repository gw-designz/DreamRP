<script lang="ts">
	import { ico } from "@/icons";
	import type { ComponentId, MDTTab } from "../constants";
	import { MDT_TABS, getTabLabel } from "../constants";
	import type { TabInstance } from "../services/tabService.svelte.ts";

	interface Props {
		instance: TabInstance;
		showCloseButton: boolean;
		onInstanceClick: (instanceId: ComponentId) => void;
		onInstanceClose: (instanceId: ComponentId, event: MouseEvent) => void;
	}

	let { instance, showCloseButton, onInstanceClick, onInstanceClose }: Props =
		$props();

	let tabIcon = $derived(
		MDT_TABS.find((t) => t.name === instance.currentTab)?.icon || "tab",
	);

	function handleInstanceClick(): void {
		onInstanceClick(instance.id);
	}

	function handleCloseClick(event: MouseEvent): void {
		event.stopPropagation();
		onInstanceClose(instance.id, event);
	}

	function handleCloseKeydown(event: KeyboardEvent): void {
		if (event.key === "Enter" || event.key === " ") {
			event.preventDefault();
			event.stopPropagation();
			// Create a synthetic mouse event for compatibility
			const syntheticEvent = new MouseEvent("click");
			onInstanceClose(instance.id, syntheticEvent);
		}
	}
</script>

<div class="instance-tab-container">
	<button
		class="instance-tab"
		class:active={instance.isActive}
		onclick={handleInstanceClick}
		aria-label="Switch to {getTabLabel(instance.currentTab)}"
	>
		<span class="tab-icon material-icons">{@html ico(tabIcon)}</span>
		<span class="tab-name">{getTabLabel(instance.currentTab)}</span>
		{#if showCloseButton}
			<span
				class="close-btn"
				onclick={handleCloseClick}
				onkeydown={handleCloseKeydown}
				aria-label="Close {getTabLabel(instance.currentTab)}"
				role="button"
				tabindex="0"
			>
				<span class="material-icons">{@html ico("close")}</span>
			</span>
		{/if}
	</button>
</div>

<style>
	.instance-tab-container {
		display: flex;
		align-items: stretch;
		position: relative;
		flex-shrink: 0;
		transition: background 0.12s ease;
	}

	.instance-tab-container::after {
		content: "";
		position: absolute;
		left: 8px;
		right: 8px;
		bottom: 0;
		height: 3px;
		border-radius: 1px;
		box-shadow: 0 0 6px transparent;
		background: transparent;
	}

	.instance-tab-container:hover {
		background: var(--hover-bg);
	}

	.instance-tab-container:has(.active)::after {
		box-shadow: 0 0 6px rgba(var(--accent-rgb), 0.7);
		background: var(--accent);
	}

	.instance-tab {
		display: flex;
		align-items: center;
		padding: 0 14px;
		text-align: left;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		gap: 6px;
		background: transparent;
		border: none;
		color: var(--primary-text);
		width: 100%;
		max-width: 190px;
	}

	.instance-tab.active {
		color: var(--accent-text);
	}

	.tab-icon {
		font-size: 15px;
		pointer-events: none;
	}

	.tab-name {
		pointer-events: none;
		flex: 1;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.close-btn {
		display: none;
		align-items: center;
		justify-content: center;
		width: 16px;
		height: 16px;
		border-radius: 3px;
		cursor: pointer;
		color: var(--primary-text);
		margin-left: 2px;
	}

	.instance-tab.active .close-btn,
	.instance-tab-container:hover .close-btn {
		display: flex;
	}

	.close-btn:hover {
		background: rgba(239, 68, 68, 0.2);
		color: #fca5a5;
	}

	.close-btn .material-icons {
		font-size: 13px;
		line-height: 1;
	}
</style>
