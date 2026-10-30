<script lang="ts">
	import { ico } from "@/icons";
	import type { ComponentId, MDTTab } from "../constants";
	import InstanceTabButton from "./InstanceTabButton.svelte";
	import type {
		TabInstance,
		createTabService,
	} from "../services/tabService.svelte.ts";
	import { globalNotifications } from "../services/notificationService.svelte";

	const MAX_TABS = 20;

	interface Props {
		tabService: ReturnType<typeof createTabService>;
		onInstanceClick?: (instanceName: string) => void;
	}

	let { tabService, onInstanceClick }: Props = $props();

	let canAddTab = $derived(tabService.instances.length < MAX_TABS);

	function handleInstanceClick(instanceId: ComponentId): void {
		tabService.setActiveInstance(instanceId);
	}

	function handleInstanceClose(instanceId: ComponentId): void {
		tabService.removeInstance(instanceId);
	}

	function handleAddNewInstance(): void {
		if (!canAddTab) {
			globalNotifications.error(`Maximum ${MAX_TABS} tabs allowed`);
			return;
		}
		const instanceNumber = tabService.instances.length + 1;
		const instanceName = `Instance ${instanceNumber}`;
		const instanceId = `instance-${Date.now()}` as ComponentId;
		tabService.addInstance(instanceId, instanceName);
	}
</script>

<div class="instance-tabs-bar">
	<div class="tabs-area">
		{#each tabService.instances as instance (instance.id)}
			<InstanceTabButton
				{instance}
				showCloseButton={tabService.instances.length > 1}
				onInstanceClick={handleInstanceClick}
				onInstanceClose={handleInstanceClose}
			/>
		{/each}

		{#if canAddTab}
			<button
				class="add-instance-btn"
				onclick={handleAddNewInstance}
				aria-label="Add new instance"
			>
				<span class="material-icons">{@html ico("add")}</span>
			</button>
		{/if}
	</div>

	<span class="tab-count" title="Open tabs">{tabService.instances.length}</span>

	{#if globalNotifications.notifications.length > 0}
		<div class="notifications-area">
			{#each globalNotifications.notifications as notif (notif.id)}
				<div class="notification {notif.type}" role="status">
					{#if notif.type === "success"}
						<span class="material-icons svg-ico" style="font-size: 11px;">{@html ico("check_plain")}</span>
					{:else if notif.type === "error"}
						<span class="material-icons svg-ico" style="font-size: 11px;">{@html ico("cancel")}</span>
					{:else}
						<span class="material-icons svg-ico" style="font-size: 11px;">{@html ico("info")}</span>
					{/if}
					<span class="notif-text">{notif.text}</span>
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.instance-tabs-bar {
		display: flex;
		align-items: stretch;
		padding: 0 12px;
		width: 100%;
		flex-shrink: 0;
		background: var(--dark-bg);
		border-bottom: 1px solid var(--border-primary);
		gap: 8px;
		min-height: 38px;
	}

	.tabs-area {
		display: flex;
		gap: 2px;
		align-items: stretch;
		overflow-x: auto;
		overflow-y: hidden;
		flex: 1;
		min-width: 0;
	}

	.tab-count {
		display: flex;
		align-items: center;
		padding: 0 6px;
		font-size: 12px;
		font-weight: 600;
		color: var(--primary-text);
		flex-shrink: 0;
	}

	.tabs-area::-webkit-scrollbar {
		height: 3px;
	}

	.tabs-area::-webkit-scrollbar-track {
		background: transparent;
	}

	.tabs-area::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.08);
		border-radius: 2px;
	}

	.notifications-area {
		display: flex;
		gap: 6px;
		align-items: center;
		flex-shrink: 0;
		overflow: hidden;
	}

	.notification {
		display: inline-flex;
		align-items: center;
		gap: 5px;
		padding: 3px 10px;
		border-radius: 4px;
		font-size: 11px;
		font-weight: 500;
		white-space: nowrap;
		animation: notif-in 0.2s ease-out;
	}

	.notification.success {
		background: rgba(16, 185, 129, 0.1);
		border: 1px solid rgba(16, 185, 129, 0.2);
		color: #6ee7b7;
	}

	.notification.error {
		background: rgba(239, 68, 68, 0.1);
		border: 1px solid rgba(239, 68, 68, 0.2);
		color: #fca5a5;
	}

	.notification.info {
		background: rgba(var(--accent-rgb), 0.1);
		border: 1px solid rgba(var(--accent-rgb), 0.2);
		color: var(--accent-text);
	}

	.notif-text {
		max-width: 250px;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.add-instance-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 24px;
		height: 24px;
		align-self: center;
		border-radius: 4px;
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.45);
		cursor: pointer;
		transition: all 0.15s ease;
		flex-shrink: 0;
		margin-left: 4px;
	}

	.add-instance-btn:hover {
		background: rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.6);
	}

	.add-instance-btn .material-icons {
		font-size: 16px;
	}

	@keyframes notif-in {
		from {
			opacity: 0;
			transform: translateX(10px);
		}
		to {
			opacity: 1;
			transform: translateX(0);
		}
	}
</style>
