<script lang="ts">
	import { ico } from "@/icons";
	import { onMount } from "svelte";
	import { formatDate as fmtDate, formatTime as fmtTime } from "../utils/datetime";
	import { fetchNui } from "../utils/fetchNui";
	import { useNuiEvent } from "../utils/useNuiEvent";
	import { debugError } from "../utils/debug";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { REPORT_TYPES } from "../constants";
	import ReportEditor from "./ReportEditor.svelte";
	import type { createInstanceStateService } from "../services/instanceStateService.svelte";
	import { createReportService } from "../services/reportService.svelte";
	import {
		pendingReportId,
		clearPendingReport,
	} from "../stores/reportsStore";
	import type { createTabService } from "../services/tabService.svelte";
	import type { MDTTab } from "../constants";
	import Pagination from "../components/Pagination.svelte";
	import SplitView from "../components/SplitView.svelte";
	import SplitRow from "../components/SplitRow.svelte";
	import SkSelect from "../components/SkSelect.svelte";
	import type { JobType } from "../interfaces/IUser";

	interface Props {
		instanceStateService: ReturnType<typeof createInstanceStateService>;
		tabService?: ReturnType<typeof createTabService>;
		jobType?: JobType;
	}

	let { instanceStateService, tabService, jobType = 'leo' }: Props = $props();

	function navigateTo(tab: MDTTab) {
		if (!tabService) return;
		tabService.setActiveTab(tab);
		const activeInstance = tabService.getActiveInstance();
		if (activeInstance) {
			tabService.setInstanceTab(activeInstance.id, tab);
		}
	}

	const reportService = createReportService();

	interface Report {
		id: string;
		title: string;
		reportId: string;
		author: string;
		authorplaintext: string;
		type: string;
		datecreated: number;
		dateupdated: number;
		tag?: string;
		tagCount?: number;
	}

	let reports: Report[] = $state([]);
	let searchQuery = $state("");
	let filterAuthor = $state("");
	let filterType = $state("");
	let filterStartDate = $state("");
	let filterEndDate = $state("");
	let analytics = $state({ incidents: 0, arrests: 0, warrants: 0 });
	let isLoading = $state(false);
	let currentPage = $state(1);
	let reportsPerPage = $state(25);
	let totalReports = $state(0);
	let showEditor = $state(false);
	let editingReportId: string | null = $state(null);
	let pendingOpenId = $state<string | null>(null);
	let searchDebounceTimer: ReturnType<typeof setTimeout> | null = null;

	$effect(() => {
		pendingOpenId = $pendingReportId;
		if (pendingOpenId) {
			editingReportId = pendingOpenId === "new" ? null : String(pendingOpenId);
			showEditor = true;
			clearPendingReport();
		}
	});

	// Split view: list folds away while a report is open; filters are tucked behind a toggle
	let listCollapsed = $state(false);
	let showFilters = $state(false);

	// Server-side search, debounced, driven by the SplitView search box
	let lastSearch = "";
	$effect(() => {
		const q = searchQuery;
		if (q === lastSearch) return;
		lastSearch = q;
		if (searchDebounceTimer) clearTimeout(searchDebounceTimer);
		searchDebounceTimer = setTimeout(() => {
			currentPage = 1;
			loadReports(1);
		}, 300);
	});

	onMount(() => {
		if (isEnvBrowser()) {
			const now = Date.now();
			reports = [
				{ id: '1', title: 'Armed Robbery at Fleeca Bank', reportId: 'RPT-001', author: 'identifier_123', authorplaintext: 'Ofc. Smith', type: 'Incident', datecreated: now - 86400000, dateupdated: now - 3600000, tag: 'Priority' },
				{ id: '2', title: 'Traffic Stop - Suspended License', reportId: 'RPT-002', author: 'identifier_123', authorplaintext: 'Ofc. Johnson', type: 'Citation', datecreated: now - 172800000, dateupdated: now - 86400000 },
				{ id: '3', title: 'Drive-by Shooting on Vinewood Blvd', reportId: 'RPT-003', author: 'identifier_123', authorplaintext: 'Det. Williams', type: 'Incident', datecreated: now - 259200000, dateupdated: now - 172800000, tag: 'Priority' },
				{ id: '4', title: 'Arrest Report - David Chen', reportId: 'RPT-004', author: 'identifier_123', authorplaintext: 'Sgt. Smith', type: 'Arrest', datecreated: now - 345600000, dateupdated: now - 259200000 },
				{ id: '5', title: 'Noise Complaint - Vespucci Beach', reportId: 'RPT-005', author: 'identifier_123', authorplaintext: 'Ofc. Brown', type: 'Incident', datecreated: now - 432000000, dateupdated: now - 345600000 },
				{ id: '6', title: 'Warrant Execution - Marcus Johnson', reportId: 'RPT-006', author: 'identifier_123', authorplaintext: 'Det. Williams', type: 'Arrest', datecreated: now - 518400000, dateupdated: now - 432000000, tag: 'Warrant' },
				{ id: '7', title: 'Hit and Run - Del Perro Pier', reportId: 'RPT-007', author: 'identifier_123', authorplaintext: 'Ofc. Smith', type: 'Incident', datecreated: now - 604800000, dateupdated: now - 518400000 },
			];
			analytics = { incidents: 4, arrests: 2, warrants: 1 };
			totalReports = 7;
			isLoading = false;
			return;
		}

		loadReports();
		loadAnalytics();

		return () => {
			if (searchDebounceTimer) {
				clearTimeout(searchDebounceTimer);
				searchDebounceTimer = null;
			}
		};
	});

	function hasActiveFilters() {
		return Boolean(
			filterStartDate ||
			filterEndDate ||
			filterType ||
			filterAuthor.trim(),
		);
	}

	useNuiEvent<{ reports: Report[] }>(
		NUI_EVENTS.REPORT.UPDATE_REPORTS,
		(data) => {
			reports = data.reports || [];
		},
	);

	async function loadReports(page: number = 1) {
		try {
			isLoading = true;
			const filters = {
				search: searchQuery.trim() || undefined,
				startDate: filterStartDate || undefined,
				endDate: filterEndDate || undefined,
				type: filterType || undefined,
				author: filterAuthor.trim() || undefined,
				limit: reportsPerPage,
			};
			const response = await fetchNui(
				NUI_EVENTS.REPORT.GET_REPORTS,
				{ page, limit: reportsPerPage, filters },
			);

			const data = response?.reports ?? response;
			reports = data?.reports || [];
			totalReports = data?.total ?? reports.length;
			currentPage = page;
		} catch (error) {
			debugError("Failed to load reports:", error);
		} finally {
			isLoading = false;
		}
	}

	async function refreshReports() {
		currentPage = 1;
		await loadReports(1);
		await loadAnalytics();
	}

	async function loadAnalytics() {
		try {
			const filters = {
				startDate: filterStartDate || undefined,
				endDate: filterEndDate || undefined,
				author: filterAuthor.trim() || undefined,
			};
			analytics = await reportService.getReportAnalytics(filters);
		} catch (error) {
			debugError("Failed to load report analytics:", error);
		}
	}

	function createNewReport() {
		editingReportId = null;
		showEditor = true;
		listCollapsed = true;
	}

	function viewReport(reportId: string) {
		editingReportId = reportId;
		showEditor = true;
		listCollapsed = true;
	}

	useNuiEvent<{ reportId: string }>(
		NUI_EVENTS.NAVIGATION.VIEW_REPORT,
		(data) => {
			if (data?.reportId) {
				viewReport(String(data.reportId));
			}
		},
	);

	function closeEditor() {
		showEditor = false;
		editingReportId = null;
		listCollapsed = false;
		refreshReports();
	}

	function formatDate(timestamp: number): string {
		return fmtDate(timestamp);
	}

	function formatTime(timestamp: number): string {
		return fmtTime(timestamp);
	}

	function getTagColor(tag: string): string {
		if (!tag) return "hsl(145 70% 45%)";
		let hash = 0;
		for (let i = 0; i < tag.length; i += 1) {
			hash = (hash << 5) - hash + tag.charCodeAt(i);
			hash |= 0;
		}
		const hue = Math.abs(hash) % 360;
		return `hsl(${hue} 70% 45%)`;
	}

	function getTypePillClass(type: string): string {
		switch (type) {
			case "Incident": return "pill pill-blue";
			case "Citation": return "pill pill-orange";
			case "Arrest": return "pill pill-red";
			default: return "pill pill-grey";
		}
	}
</script>

<SplitView
	bind:query={searchQuery}
	bind:collapsed={listCollapsed}
	placeholder="Search Title, ID, Author or Tag"
	loading={isLoading && reports.length === 0}
	loadingText="Loading reports..."
	hasSelection={showEditor}
	emptyIcon="description"
	emptyTitle="No report selected"
	emptySub="Select a report from the list, or create a new one"
>
	{#snippet actions()}
		<button class="sk-btn sk-accent" style="height: 38px;" onclick={createNewReport} title="New report">
			<span class="material-icons">{@html ico("add")}</span> New
		</button>
	{/snippet}

	{#snippet toolbar()}
		<div class="report-stats">
			<span class="report-stat"><span class="material-icons stat-blue">{@html ico("description")}</span>{analytics.incidents} Incidents</span>
			<span class="report-stat"><span class="material-icons stat-red">{@html ico("block")}</span>{analytics.arrests} Arrests</span>
			<span class="report-stat"><span class="material-icons stat-amber">{@html ico("warning")}</span>{analytics.warrants} Warrants</span>
		</div>
		<div class="split-tool-row">
			<button class="split-filter" class:active={showFilters || hasActiveFilters()} onclick={() => (showFilters = !showFilters)}>
				Filters{hasActiveFilters() ? " •" : ""}
			</button>
			<button class="split-filter" onclick={refreshReports} disabled={isLoading}>Refresh</button>
		</div>
		{#if showFilters}
			<div class="filter-grid">
				<div class="sk-field"><input type="date" bind:value={filterStartDate} aria-label="Filter start date" /></div>
				<div class="sk-field"><input type="date" bind:value={filterEndDate} aria-label="Filter end date" /></div>
				<SkSelect
					bind:value={filterType}
					options={[{ value: "", label: "All Types" }, ...REPORT_TYPES.map((t) => ({ value: t, label: t }))]}
				/>
				<div class="sk-field"><input type="text" placeholder="Author" bind:value={filterAuthor} aria-label="Filter author" /></div>
			</div>
			<div class="split-tool-row">
				<button class="sk-btn sk-sm sk-accent" onclick={refreshReports} disabled={isLoading}>Apply</button>
				<button
					class="sk-btn sk-sm"
					onclick={() => {
						filterStartDate = "";
						filterEndDate = "";
						filterType = "";
						filterAuthor = "";
						refreshReports();
					}}
					disabled={isLoading || !hasActiveFilters()}
				>Clear</button>
			</div>
		{/if}
	{/snippet}

	{#snippet list()}
		{#if reports.length === 0}
			<div class="split-none">
				{searchQuery ? "No reports match your search." : "No reports have been created yet."}
			</div>
		{:else}
			{#each reports as report (report.id)}
				<SplitRow
					title={report.title}
					subtitle="#{report.reportId} · {report.authorplaintext || report.author} · {formatDate(report.datecreated)}"
					icon="description"
					active={showEditor && editingReportId === report.id}
					onclick={() => viewReport(report.id)}
				>
					{#snippet trailing()}
						<span class={getTypePillClass(report.type)}>{report.type}</span>
						{#if report.tag}
							<span
								class="pill tag-pill"
								style="background: {getTagColor(report.tag)}22; color: {getTagColor(report.tag)}; border: 1px solid {getTagColor(report.tag)}33;"
							>{report.tag}{#if (report.tagCount ?? 0) > 1}&nbsp;+{(report.tagCount ?? 0) - 1}{/if}</span>
						{/if}
					{/snippet}
				</SplitRow>
			{/each}
		{/if}
	{/snippet}

	{#snippet footer()}
		<Pagination
			currentPage={currentPage}
			totalItems={totalReports}
			perPage={reportsPerPage}
			onPageChange={(p) => loadReports(p)}
			onPerPageChange={(pp) => { reportsPerPage = pp; loadReports(1); }}
		/>
	{/snippet}

	{#snippet detail()}
		{#key editingReportId ?? "new"}
			<ReportEditor
				reportId={editingReportId}
				onClose={closeEditor}
				{instanceStateService}
				{tabService}
				{jobType}
			/>
		{/key}
	{/snippet}
</SplitView>

<style>
	/* ===== Split view list extras ===== */
	.report-stats { display: flex; gap: 6px; flex-wrap: wrap; }
	.report-stat { display: inline-flex; align-items: center; gap: 5px; padding: 3px 9px; font-size: 12px; font-weight: 700; color: #fff; background: rgba(255, 255, 255, 0.03); border: 1px solid var(--border-primary); border-radius: 3px; }
	.report-stat .material-icons { font-size: 15px; }
	.stat-blue { color: var(--accent-text); }
	.stat-red { color: #f87171; }
	.stat-amber { color: #fbbf24; }
	.filter-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px 14px; }
	.filter-grid .sk-field > input { padding-right: 10px; color-scheme: dark; }
	.reports-page {
		height: 100%;
		display: flex;
		flex-direction: column;
		background: var(--card-dark-bg);
		overflow: hidden;
	}

	.topbar {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 0 20px;
		height: 48px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.topbar-left {
		flex: 1;
		min-width: 0;
	}

	.topbar-right {
		display: flex;
		align-items: center;
		gap: 6px;
		flex-shrink: 0;
	}

	.search-box {
		display: flex;
		align-items: center;
		gap: 8px;
		background: transparent;
		border: none;
		padding: 0;
		max-width: 420px;
		color: rgba(255, 255, 255, 0.3);
	}

	.search-box input {
		background: transparent;
		border: none;
		color: rgba(255, 255, 255, 0.9);
		font-size: 12px;
		padding: 0;
		width: 100%;
		outline: none;
	}

	.search-box input::placeholder {
		color: rgba(255, 255, 255, 0.35);
	}

	.filter-input {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 4px;
		padding: 5px 8px;
		color: rgba(255, 255, 255, 0.7);
		font-size: 11px;
		outline: none;
		transition: border-color 0.15s ease;
		color-scheme: dark;
	}

	.filter-select {
		border-radius: 4px;
		padding: 5px 24px 5px 8px;
		font-size: 11px;
	}

	.filter-input:focus,
	.filter-select:focus {
		border-color: rgba(255, 255, 255, 0.15);
	}

	.filter-input::-webkit-calendar-picker-indicator {
		filter: invert(0.5);
		cursor: pointer;
	}

	.filter-author {
		width: 80px;
	}

	.topbar-btn {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 4px;
		padding: 5px 12px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 11px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.15s ease;
		white-space: nowrap;
	}

	.topbar-btn:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.04);
		color: rgba(255, 255, 255, 0.7);
	}

	.topbar-btn:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.btn-primary {
		background: rgba(var(--accent-rgb), 0.1);
		color: rgba(var(--accent-text-rgb), 0.8);
		border-color: rgba(var(--accent-rgb), 0.2);
	}

	.btn-primary:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.18);
		color: var(--accent-text);
	}

	.analytics-strip {
		display: flex;
		align-items: center;
		padding: 0 20px;
		height: 40px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		gap: 0;
	}

	.stat-item {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 0 16px;
	}

	.stat-item:first-child {
		padding-left: 0;
	}

	.stat-icon {
		opacity: 0.7;
		flex-shrink: 0;
	}

	.stat-icon-blue { color: var(--accent-text); }
	.stat-icon-red { color: #f87171; }
	.stat-icon-amber { color: #fbbf24; }

	.stat-value {
		font-size: 14px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}

	.stat-label {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.3);
		text-transform: uppercase;
		letter-spacing: 0.5px;
		font-weight: 500;
	}

	.stat-divider {
		width: 1px;
		height: 18px;
		background: rgba(255, 255, 255, 0.06);
		flex-shrink: 0;
	}

	.list-panel {
		background: transparent;
		border: none;
		border-radius: 0;
		flex: 1;
		min-height: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.list-header {
		display: grid;
		grid-template-columns: 2fr 0.8fr 1fr 0.8fr 0.8fr 0.8fr 0.8fr;
		gap: 12px;
		padding: 8px 20px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.8px;
		flex-shrink: 0;
	}

	.list-body {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
		scrollbar-width: thin;
		scrollbar-color: rgba(255, 255, 255, 0.08) transparent;
	}

	.list-body::-webkit-scrollbar { width: 3px; }
	.list-body::-webkit-scrollbar-track { background: transparent; }
	.list-body::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.08); border-radius: 2px; }

	.report-row {
		display: grid;
		grid-template-columns: 2fr 0.8fr 1fr 0.8fr 0.8fr 0.8fr 0.8fr;
		gap: 12px;
		padding: 9px 20px;
		align-items: center;
		border: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		background: transparent;
		cursor: pointer;
		transition: background 0.12s ease;
		width: 100%;
		text-align: left;
		font: inherit;
		color: inherit;
	}

	.report-row:hover {
		background: rgba(255, 255, 255, 0.03);
	}

	.col-title {
		color: rgba(255, 255, 255, 0.85);
		font-size: 12px;
		font-weight: 500;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.col-id {
		color: rgba(255, 255, 255, 0.4);
		font-size: 11px;
	}

	.col-author {
		display: flex;
		color: rgba(255, 255, 255, 0.4);
		font-size: 11px;
		align-items: center;
		gap: 5px;
		overflow: hidden;
	}

	.author-badge {
		background: rgba(var(--accent-rgb), 0.1);
		border: 1px solid rgba(var(--accent-rgb), 0.2);
		color: rgba(var(--accent-text-rgb), 0.8);
		font-size: 9px;
		font-weight: 600;
		padding: 1px 5px;
		border-radius: 3px;
		letter-spacing: 0.3px;
		white-space: nowrap;
		flex-shrink: 0;
	}

	.author-badge.no-callsign {
		background: rgba(255, 255, 255, 0.03);
		border-color: rgba(255, 255, 255, 0.06);
		color: rgba(255, 255, 255, 0.35);
	}

	.col-type {
		display: flex;
		align-items: center;
	}

	.col-date {
		color: rgba(255, 255, 255, 0.35);
		font-size: 11px;
	}

	.col-tag {
		display: flex;
		align-items: center;
	}

	.mono {
		font-family: var(--font-main);
		letter-spacing: 0.5px;
	}

	.pill {
		padding: 2px 7px;
		border-radius: 3px;
		font-size: 10px;
		font-weight: 600;
		letter-spacing: 0.3px;
		white-space: nowrap;
	}

	.pill-blue {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.8);
		border: 1px solid rgba(var(--accent-rgb), 0.15);
	}

	.pill-orange {
		background: rgba(245, 158, 11, 0.12);
		color: rgba(251, 191, 36, 0.8);
		border: 1px solid rgba(245, 158, 11, 0.15);
	}

	.pill-red {
		background: rgba(239, 68, 68, 0.12);
		color: rgba(248, 113, 113, 0.8);
		border: 1px solid rgba(239, 68, 68, 0.15);
	}

	.pill-grey {
		background: rgba(107, 114, 128, 0.12);
		color: rgba(156, 163, 175, 0.8);
		border: 1px solid rgba(107, 114, 128, 0.15);
	}

	.tag-pill {
		border-radius: 3px;
		text-transform: uppercase;
	}

	.tag-more {
		font-size: 9px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.2);
		margin-left: 2px;
		white-space: nowrap;
	}

	.empty-state {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 60px 20px;
		color: rgba(255, 255, 255, 0.3);
		font-size: 12px;
	}

	.empty-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		gap: 4px;
	}

	.empty-title {
		color: rgba(255, 255, 255, 0.4);
		font-size: 14px;
		font-weight: 600;
	}

	.empty-sub {
		color: rgba(255, 255, 255, 0.35);
		font-size: 12px;
	}

	.loading-spinner {
		width: 20px;
		height: 20px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(255, 255, 255, 0.25);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-right: 10px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}
</style>