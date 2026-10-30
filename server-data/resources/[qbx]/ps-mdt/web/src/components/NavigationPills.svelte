<script lang="ts">
	import { ico } from "@/icons";
	import { MDT_TABS, NAV_GROUPS, DOJ_NAV_GROUPS, getTabsForJob, getTabLabel, type MDTTab } from "../constants";
	import type { createTabService } from "../services/tabService.svelte";
	import type { JobType } from "../interfaces/IUser";
	import type { AuthService } from "../services/authService.svelte";
	import { globalNotifications } from "../services/notificationService.svelte";

	const MAX_TABS = 20;

	interface Props {
		tabService: ReturnType<typeof createTabService>;
		jobType?: JobType;
		authService?: AuthService;
		onSelect?: () => void;
	}

	let { tabService, jobType = 'leo', authService, onSelect }: Props = $props();

	function isTabHidden(tabName: string): boolean {
		if (!authService) return false;
		const key = `tab_hidden_${tabName.toLowerCase()}`;
		return authService.hasRawPermission(key);
	}

	let visibleTabs = $derived(getTabsForJob(jobType).filter(t => !isTabHidden(t.name)));
	let visibleTabNames = $derived(new Set(visibleTabs.map(t => t.name)));

	function handleTabClick(tabName: MDTTab) {
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, tabName);
		} else {
			tabService.setActiveTab(tabName);
		}
		onSelect?.();
	}

	function handleOpenNewTab(event: MouseEvent, tabName: MDTTab) {
		event.stopPropagation();
		if (tabService.instances.length >= MAX_TABS) {
			globalNotifications.error(`Maximum ${MAX_TABS} tabs allowed`);
			return;
		}
		tabService.openInNewInstance(tabName);
		onSelect?.();
	}

	// Middle-click opens the page in a new tab, like a browser
	function handleAuxClick(event: MouseEvent, tabName: MDTTab) {
		if (event.button === 1) handleOpenNewTab(event, tabName);
	}

	function getTabData(tabName: string) {
		return MDT_TABS.find(t => t.name === tabName);
	}

	let navGroups = $derived(jobType === 'doj' ? DOJ_NAV_GROUPS : NAV_GROUPS);

	let visibleGroups = $derived.by(() => {
		return navGroups
			.map(group => ({
				...group,
				visibleTabs: group.tabs.filter(t => visibleTabNames.has(t as MDTTab)),
			}))
			.filter(g => g.visibleTabs.length > 0);
	});

	let activeTab = $derived(tabService.getActiveInstanceTab());
	$effect(() => {
		if (activeTab && !visibleTabNames.has(activeTab)) {
			const inst = tabService.getActiveInstance();
			if (inst) tabService.setInstanceTab(inst.id, "Dashboard");
		}
	});
</script>

<div class="nav-menu" role="menu">
	{#each visibleGroups as group}
		<div class="nav-section">{group.label ?? (group.id === "bottom" ? "System" : "Main")}</div>
		{#each group.visibleTabs as tabName}
			{@const tab = getTabData(tabName)}
			{#if tab}
				<button
					class="nav-item"
					class:active={activeTab === tab.name}
					role="menuitem"
					onclick={() => handleTabClick(tab.name)}
					onauxclick={(e) => handleAuxClick(e, tab.name)}
				>
					<span class="material-icons nav-icon">{@html ico(tab.icon)}</span>
					<span class="nav-label">{getTabLabel(tab.name)}</span>
					<span
						class="new-tab"
						role="button"
						tabindex="-1"
						title="Open in new tab"
						onclick={(e) => handleOpenNewTab(e, tab.name)}
						onkeydown={() => {}}
					></span>
				</button>
			{/if}
		{/each}
	{/each}
</div>

<style>
	.nav-menu {
		width: 248px;
		max-height: 420px;
		overflow-y: auto;
		padding: 6px 0;
		background: var(--menu-bg);
		border: 1px solid var(--border-primary);
		border-radius: 6px;
		box-shadow: 0 16px 40px rgba(0, 0, 0, 0.5);
	}

	.nav-section {
		padding: 10px 14px 4px;
		font-size: 11px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.3px;
		color: var(--secondary-text);
	}

	.nav-item {
		display: flex;
		align-items: center;
		gap: 12px;
		width: 100%;
		padding: 8px 14px;
		background: none;
		border: none;
		color: var(--primary-text);
		font-size: 14px;
		font-weight: 500;
		text-align: left;
		cursor: pointer;
		transition: background 0.12s ease;
	}

	.nav-item:hover {
		background: var(--hover-bg);
	}

	.nav-item.active {
		background: var(--accent-10);
		color: var(--accent-text);
	}

	.nav-icon {
		font-size: 18px;
		width: 20px;
		color: var(--secondary-text);
	}

	.nav-item.active .nav-icon {
		color: var(--accent-text);
	}

	.nav-label {
		flex: 1;
	}

	/* Small dot on the right — click to open the page in a new tab */
	.new-tab {
		width: 16px;
		height: 16px;
		border-radius: 4px;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.new-tab::after {
		content: "";
		width: 4px;
		height: 4px;
		border-radius: 50%;
		background: var(--secondary-text);
	}

	.new-tab:hover {
		background: var(--accent-20);
	}

	.new-tab:hover::after {
		background: var(--accent-text);
	}
</style>
