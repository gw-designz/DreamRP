<script lang="ts">
	import { ico } from "@/icons";
	// Inline hover tooltip rendered into <body> so it is never clipped by a
	// scrolling/overflow parent (same idea as the dashboard MOTD tooltip, but
	// floated to body and shown below the target so it never covers neighbours).
	function tip(node: HTMLElement, text: string | undefined) {
		let el: HTMLDivElement | null = null;
		let cur = text;
		function place(e: MouseEvent) {
			if (!el) return;
			const t = el.getBoundingClientRect();
			let x = e.clientX + 14;
			let y = e.clientY + 16;
			if (x + t.width > window.innerWidth - 4) x = e.clientX - t.width - 14;
			if (y + t.height > window.innerHeight - 4) y = e.clientY - t.height - 16;
			el.style.left = `${Math.max(4, x)}px`;
			el.style.top = `${Math.max(4, y)}px`;
		}
		function show(e: MouseEvent) {
			if (!cur || el) return;
			el = document.createElement("div");
			el.textContent = cur;
			el.style.cssText = "position:fixed;z-index:99999;background:#111113;color:rgba(255,255,255,0.92);padding:6px 9px;border-radius:5px;font-size:11px;font-weight:500;line-height:1.4;max-width:240px;white-space:normal;word-break:break-word;border:1px solid rgba(255,255,255,0.12);box-shadow:0 8px 24px rgba(0,0,0,0.6);pointer-events:none;";
			document.body.appendChild(el);
			place(e);
		}
		function move(e: MouseEvent) { if (el) place(e); }
		function hide() { if (el) { el.remove(); el = null; } }
		node.addEventListener("mouseenter", show);
		node.addEventListener("mousemove", move);
		node.addEventListener("mouseleave", hide);
		return {
			update(v: string | undefined) { cur = v; if (el && !v) hide(); },
			destroy() { hide(); node.removeEventListener("mouseenter", show); node.removeEventListener("mousemove", move); node.removeEventListener("mouseleave", hide); },
		};
	}

	import { onMount } from "svelte";
	import { formatDate } from "../utils/datetime";
	import { fetchNui } from "../utils/fetchNui";
	import { useNuiEvent } from "../utils/useNuiEvent";
	import { debugData } from "../utils/debugData";
	import { isEnvBrowser } from "../utils/misc";
	import { NUI_EVENTS } from "../constants/nuiEvents";
	import { globalNotifications } from "../services/notificationService.svelte";
	import type { AuthService } from "../services/authService.svelte";
	import ActivityTimeline from "../components/ActivityTimeline.svelte";
	import SplitView from "../components/SplitView.svelte";
	import SplitRow from "../components/SplitRow.svelte";
	import SkSelect from "../components/SkSelect.svelte";

	let { authService, tabService }: { authService?: AuthService; tabService?: any } = $props();

	interface Officer {
		id: string;
		callsign: string;
		firstName: string;
		lastName: string;
		rank: string;
		department?: string;
		departmentLabel?: string;
		status: "On Duty" | "Off Duty";
		certifications: string[];
		badgeNumber: string;
		citizenid?: string;
		radioChannel?: number;
	}

	interface ActiveUnit {
		id: string;
		badgeNumber: string;
		firstName: string;
		lastName: string;
		callsign: string;
	}

	interface OfficerTag {
		id: number;
		name: string;
		color: string;
		description?: string;
	}

	interface JobGrade {
		grade: number;
		name: string;
		isBoss: boolean;
	}

	let officers = $state<Officer[]>([]);
	let activeUnits = $state<ActiveUnit[]>([]);
	let isLoading = $state(false);
	let searchQuery = $state("");
	let sortColumn = $state<string>("");
	let sortDirection = $state<"asc" | "desc">("asc");

	// Certification modal state
	let selectedOfficer = $state<Officer | null>(null);
	let availableTags = $state<OfficerTag[]>([]);
	let selectedCerts = $state<string[]>([]);
	let isSavingCerts = $state(false);
	let showCertModal = $state(false);

	// Boss panel state
	let showBossPanel = $state(false);
	let bossPanelTab = $state<"rank" | "callsign" | "certs" | "ppr" | "fto" | "ia_history" | "activity">("rank");
	let iaHistory = $state<Array<{ id: number; complaint_number: string; category: string; status: string; created_at: string }>>([]);
	let iaHistoryLoading = $state(false);
	let pprHistory = $state<Array<{ id: number; ppr_number: string; category: string; title: string; author_name: string; incident_date?: string; created_at: string }>>([]);
	let pprHistoryLoading = $state(false);
	let ftoHistory = $state<Array<{ id: number; fto_number: string; status: string; trainer_name: string; trainee_name: string; phase_name?: string; start_date?: string; dor_count?: number; latest_rating?: number; created_at: string }>>([]);
	let ftoHistoryLoading = $state(false);
	let jobGrades = $state<JobGrade[]>([]);
	let selectedGrade = $state<number | null>(null);
	let editCallsign = $state("");
	let isSavingBoss = $state(false);
	let showFireConfirm = $state(false);

	let canManageCerts = $derived(authService?.hasPermission("roster_manage_certifications") ?? false);
	let canManageOfficers = $derived(authService?.hasPermission("roster_manage_officers") ?? false);
	let canOpenPanel = $derived(canManageCerts || canManageOfficers);

	// Phase 2: EMS-aware terminology. The roster is shared UI but the wording
	// should match the caller's domain (police "Officer" vs EMS "Personnel").
	let isEmsDomain = $derived((authService?.jobType ?? "leo") === "ems");
	let term = $derived({
		member: isEmsDomain ? "Personnel" : "Officer",
		members: isEmsDomain ? "Personnel" : "Officers",
		memberLower: isEmsDomain ? "member" : "officer",
		membersLower: isEmsDomain ? "members" : "officers",
		management: isEmsDomain ? "Personnel Management" : "Officer Management",
		terminate: isEmsDomain ? "Terminate Member" : "Terminate Officer",
		removeHint: isEmsDomain
			? "Remove this person from the department. This sets their job to unemployed."
			: "Remove this officer from the department. This sets their job to unemployed.",
	});

	// Split view: officer shown in the right pane (looked up by id so rank/callsign
	// edits and terminations reflect immediately)
	let viewedOfficerId = $state<string | null>(null);
	let viewedOfficer = $derived(officers.find((o) => o.id === viewedOfficerId) ?? null);
	let departmentFilter = $state("all");
	let statusFilter = $state<"all" | "on">("all");

	function deptName(o: Officer): string {
		return o.departmentLabel || o.department || "Unknown";
	}

	let departments = $derived([...new Set(officers.map(deptName))].sort());

	let filteredOfficers = $derived.by(() => {
		const query = searchQuery.trim().toLowerCase();
		let filtered = !query
			? officers
			: officers.filter(({ callsign, firstName, lastName, rank }) =>
					[callsign, firstName, lastName, rank].some((val) =>
						val.toLowerCase().includes(query),
					),
				);
		if (departmentFilter !== "all") filtered = filtered.filter((o) => deptName(o) === departmentFilter);
		if (statusFilter === "on") filtered = filtered.filter((o) => o.status === "On Duty");

		if (sortColumn) {
			filtered = [...filtered].sort((a, b) => {
				let aVal: string | number = "";
				let bVal: string | number = "";

				switch (sortColumn) {
					case "name":
						aVal = `${a.firstName} ${a.lastName}`;
						bVal = `${b.firstName} ${b.lastName}`;
						break;
					case "callsign":
						aVal = a.callsign;
						bVal = b.callsign;
						break;
					case "rank":
						aVal = a.rank;
						bVal = b.rank;
						break;
					case "status":
						aVal = a.status;
						bVal = b.status;
						break;
				}

				if (typeof aVal === "string" && typeof bVal === "string") {
					const result = aVal.localeCompare(bVal);
					return sortDirection === "asc" ? result : -result;
				}
				return 0;
			});
		}

		return filtered;
	});

	onMount(() => {
		if (isEnvBrowser()) {
			officers = [
				{
					id: "1",
					callsign: "401",
					firstName: "John",
					lastName: "Smith",
					rank: "Chief of Police",
					department: "lspd",
					status: "On Duty",
					certifications: ["FTO", "SWAT", "Interceptor"],
					badgeNumber: "1001",
					citizenid: "ABC12345",
					radioChannel: 1,
				},
				{
					id: "2",
					callsign: "455",
					firstName: "Jane",
					lastName: "Doe",
					rank: "Lieutenant",
					department: "lspd",
					status: "On Duty",
					certifications: ["Air Certified", "FTO"],
					badgeNumber: "1002",
					citizenid: "DEF67890",
					radioChannel: 1,
				},
				{
					id: "3",
					callsign: "474",
					firstName: "Mike",
					lastName: "Johnson",
					rank: "Sergeant",
					department: "bcso",
					status: "Off Duty",
					certifications: ["SWAT"],
					badgeNumber: "1003",
					citizenid: "GHI11111",
					radioChannel: 0,
				},
				{
					id: "4",
					callsign: "402",
					firstName: "Sarah",
					lastName: "Wilson",
					rank: "Officer",
					department: "lspd",
					status: "On Duty",
					certifications: [],
					badgeNumber: "1004",
					citizenid: "JKL22222",
					radioChannel: 2,
				},
				{
					id: "5",
					callsign: "472",
					firstName: "David",
					lastName: "Brown",
					rank: "Detective",
					department: "sahp",
					status: "Off Duty",
					certifications: ["FTO"],
					badgeNumber: "1005",
					citizenid: "MNO33333",
					radioChannel: 0,
				},
			];

			activeUnits = [
				{ id: "1", badgeNumber: "1001", firstName: "John", lastName: "Smith", callsign: "401" },
				{ id: "2", badgeNumber: "1002", firstName: "Jane", lastName: "Doe", callsign: "455" },
				{ id: "4", badgeNumber: "1004", firstName: "Sarah", lastName: "Wilson", callsign: "402" },
			];

			availableTags = [
				{ id: 1, name: "SWAT", color: "#3b82f6" },
				{ id: 2, name: "FTO", color: "#10b981" },
				{ id: 3, name: "Detective", color: "#8b5cf6" },
				{ id: 4, name: "K9 Certified", color: "#06b6d4" },
				{ id: 5, name: "Air Certified", color: "#ec4899" },
				{ id: 6, name: "Command", color: "#ef4444" },
			];
		} else {
			loadRoster();
			loadOfficerTags();
		}
	});

	useNuiEvent<Officer[]>(NUI_EVENTS.ROSTER.GET_ROSTER, (data: Officer[]) => {
		officers = Array.isArray(data) ? data : [];
	});

	useNuiEvent<ActiveUnit[]>(
		NUI_EVENTS.ROSTER.GET_ACTIVE_UNITS,
		(data: ActiveUnit[]) => {
			activeUnits = Array.isArray(data) ? data : [];
		},
	);

	async function loadRoster() {
		try {
			isLoading = true;
			const response = await fetchNui(NUI_EVENTS.ROSTER.GET_ROSTER);
			officers = Array.isArray(response.roster) ? response.roster : [];
			activeUnits = Array.isArray(response.activeUnits)
				? response.activeUnits
				: [];
		} catch (error) {
			globalNotifications.error("Failed to load roster");
			officers = [];
		} finally {
			isLoading = false;
		}
	}

	async function loadOfficerTags() {
		if (isEnvBrowser()) return;
		try {
			const tags = await fetchNui(NUI_EVENTS.ROSTER.GET_OFFICER_TAGS);
			availableTags = Array.isArray(tags) ? tags : [];
		} catch {
			availableTags = [];
		}
	}

	async function loadJobGrades(department: string) {
		if (isEnvBrowser()) {
			// Dev mock: derive grades from the officer mock data ranks
			const uniqueRanks = [...new Set(officers.map((o) => o.rank))];
			jobGrades = uniqueRanks.map((name, i) => ({
				grade: i,
				name,
				isBoss: i === uniqueRanks.length - 1,
			}));
			return;
		}
		try {
			const grades = await fetchNui<JobGrade[]>(NUI_EVENTS.ROSTER.GET_JOB_GRADES, { job: department });
			jobGrades = Array.isArray(grades) ? grades : [];
		} catch {
			jobGrades = [];
		}
	}

	function handleSort(column: string) {
		if (sortColumn === column) {
			sortDirection = sortDirection === "asc" ? "desc" : "asc";
		} else {
			sortColumn = column;
			sortDirection = "asc";
		}
	}

	function getSortIndicator(column: string): string {
		if (sortColumn !== column) return "";
		return sortDirection === "asc" ? " ↑" : " ↓";
	}

	function refreshData() {
		if (!isEnvBrowser()) {
			loadRoster();
		}
	}

	async function openOfficerPanel(officer: Officer, tab: typeof bossPanelTab = "rank", fire = false) {
		if (!canOpenPanel) return;

		selectedOfficer = officer;
		selectedCerts = [...(officer.certifications || [])];
		editCallsign = officer.callsign || "";
		selectedGrade = null;
		showFireConfirm = fire;

		if (canManageOfficers) {
			// Open boss panel with all tabs
			bossPanelTab = tab;
			await Promise.all([
				loadOfficerTags(),
				loadJobGrades(officer.department || "police"),
			]);
			showBossPanel = true;
		} else {
			// Fall back to cert-only modal
			await loadOfficerTags();
			showCertModal = true;
		}
	}

	function closeBossPanel() {
		showBossPanel = false;
		showFireConfirm = false;
		selectedOfficer = null;
		selectedCerts = [];
		editCallsign = "";
		selectedGrade = null;
		jobGrades = [];
	}

	function closeCertModal() {
		showCertModal = false;
		selectedOfficer = null;
		selectedCerts = [];
	}

	function toggleCert(tagName: string) {
		if (selectedCerts.includes(tagName)) {
			selectedCerts = selectedCerts.filter((c) => c !== tagName);
		} else {
			selectedCerts = [...selectedCerts, tagName];
		}
	}

	async function saveCertifications() {
		if (!selectedOfficer?.citizenid) return;
		isSavingCerts = true;
		try {
			const response = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.ROSTER.UPDATE_OFFICER_CERTIFICATIONS,
				{
					citizenid: selectedOfficer.citizenid,
					certifications: selectedCerts,
				},
			);
			if (response?.success) {
				const idx = officers.findIndex((o) => o.citizenid === selectedOfficer!.citizenid);
				if (idx !== -1) {
					officers[idx].certifications = [...selectedCerts];
				}
				globalNotifications.success(`Updated certifications for ${selectedOfficer.firstName} ${selectedOfficer.lastName}`);
				if (showBossPanel) {
					// Stay on boss panel, just show success
				} else {
					closeCertModal();
				}
			} else {
				globalNotifications.error(response?.message || "Failed to update certifications");
			}
		} catch {
			globalNotifications.error("Failed to update certifications");
		} finally {
			isSavingCerts = false;
		}
	}

	async function promoteOfficer() {
		if (!selectedOfficer?.citizenid || selectedGrade === null) return;
		isSavingBoss = true;
		try {
			const response = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.ROSTER.PROMOTE_OFFICER,
				{
					citizenid: selectedOfficer.citizenid,
					job: selectedOfficer.department || "police",
					grade: selectedGrade,
				},
			);
			if (response?.success) {
				const gradeName = jobGrades.find((g) => g.grade === selectedGrade)?.name || `Grade ${selectedGrade}`;
				const idx = officers.findIndex((o) => o.citizenid === selectedOfficer!.citizenid);
				if (idx !== -1) {
					officers[idx].rank = gradeName;
				}
				globalNotifications.success(response.message || `Rank updated to ${gradeName}`);
			} else {
				globalNotifications.error(response?.message || "Failed to update rank");
			}
		} catch {
			globalNotifications.error("Failed to update rank");
		} finally {
			isSavingBoss = false;
		}
	}

	let deleteUserData = $state(false);

	async function fireOfficer() {
		if (!selectedOfficer?.citizenid) return;
		isSavingBoss = true;
		try {
			const response = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.ROSTER.FIRE_OFFICER,
				{ citizenid: selectedOfficer.citizenid, deleteData: deleteUserData },
			);
			if (response?.success) {
				officers = officers.filter((o) => o.citizenid !== selectedOfficer!.citizenid);
				globalNotifications.success(response.message || `${term.member} has been terminated`);
				closeBossPanel();
			} else {
				globalNotifications.error(response?.message || `Failed to terminate ${term.memberLower}`);
			}
		} catch {
			globalNotifications.error(`Failed to terminate ${term.memberLower}`);
		} finally {
			isSavingBoss = false;
			showFireConfirm = false;
			deleteUserData = false;
		}
	}

	async function loadIAHistory() {
		if (!selectedOfficer) return;
		iaHistoryLoading = true;
		try {
			const officerName = `${selectedOfficer.firstName} ${selectedOfficer.lastName}`;
			const result = await fetchNui<Array<{ id: number; complaint_number: string; category: string; status: string; created_at: string }>>(
				NUI_EVENTS.IA.GET_IA_HISTORY_FOR_OFFICER,
				{ officerName, officerCid: selectedOfficer.citizenid },
				[]
			);
			iaHistory = Array.isArray(result) ? result : [];
		} catch {
			iaHistory = [];
		}
		iaHistoryLoading = false;
	}

	function formatIAStatus(status: string): string {
		return status.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
	}

	function getIAStatusClass(status: string): string {
		switch (status) {
			case 'open': return 'pill-blue';
			case 'under_review': return 'pill-orange';
			case 'investigated': return 'pill-yellow';
			case 'sustained': return 'pill-red';
			case 'exonerated': return 'pill-green';
			default: return 'pill-gray';
		}
	}

	async function loadOfficerPPR() {
		if (!selectedOfficer?.citizenid) return;
		pprHistoryLoading = true;
		try {
			const result = await fetchNui<Array<{ id: number; ppr_number: string; category: string; title: string; author_name: string; incident_date?: string; created_at: string }>>(
				NUI_EVENTS.PPR.GET_OFFICER_PPR_HISTORY,
				{ officerCitizenId: selectedOfficer.citizenid },
				[]
			);
			pprHistory = Array.isArray(result) ? result : [];
		} catch {
			pprHistory = [];
		}
		pprHistoryLoading = false;
	}

	async function loadOfficerFTO() {
		if (!selectedOfficer?.citizenid) return;
		ftoHistoryLoading = true;
		try {
			const result = await fetchNui<Array<any>>(
				NUI_EVENTS.FTO.GET_OFFICER_FTO_HISTORY,
				{ officerCitizenId: selectedOfficer.citizenid },
				[]
			);
			ftoHistory = Array.isArray(result) ? result : [];
		} catch {
			ftoHistory = [];
		}
		ftoHistoryLoading = false;
	}

	function getFTOStatusClass(status: string): string {
		switch (status) {
			case 'active': return 'status-active';
			case 'completed': return 'status-completed';
			case 'failed': return 'status-failed';
			case 'suspended': return 'status-suspended';
			default: return '';
		}
	}

	function getPPRCategoryClass(category: string): string {
		switch (category) {
			case 'positive': return 'pill-green';
			case 'coaching': return 'pill-orange';
			case 'disciplinary': return 'pill-red';
			default: return 'pill-gray';
		}
	}

	function formatPPRCategory(category: string): string {
		return category.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
	}

	function formatDateShort(dateStr: string): string {
		return formatDate(dateStr, "");
	}

	async function saveCallsign() {
		if (!selectedOfficer?.citizenid || !editCallsign.trim()) return;
		isSavingBoss = true;
		try {
			const response = await fetchNui<{ success: boolean; message?: string }>(
				NUI_EVENTS.ROSTER.UPDATE_CALLSIGN,
				{
					citizenid: selectedOfficer.citizenid,
					callsign: editCallsign.trim(),
				},
			);
			if (response?.success) {
				const idx = officers.findIndex((o) => o.citizenid === selectedOfficer!.citizenid);
				if (idx !== -1) {
					officers[idx].callsign = editCallsign.trim();
					officers[idx].badgeNumber = editCallsign.trim();
				}
				globalNotifications.success(response.message || `Callsign updated to ${editCallsign.trim()}`);
			} else {
				globalNotifications.error(response?.message || "Failed to update callsign");
			}
		} catch {
			globalNotifications.error("Failed to update callsign");
		} finally {
			isSavingBoss = false;
		}
	}

	function getTagColor(certName: string): string {
		const tag = availableTags.find((t) => t.name === certName);
		return tag?.color || "#6b7280";
	}
	function getTagDescription(certName: string): string {
		return availableTags.find((t) => t.name === certName)?.description || "";
	}

	async function copyText(value: string) {
		if (!value) return;
		try {
			await fetchNui("copyToClipboard", { text: value });
			globalNotifications.success("Copied to clipboard");
		} catch {
			try {
				await navigator.clipboard?.writeText(value);
			} catch {
				// silent
			}
		}
	}
</script>

<SplitView
	bind:query={searchQuery}
	placeholder="Search Callsign, Name or Rank"
	loading={isLoading}
	loadingText="Loading roster..."
	hasSelection={!!viewedOfficer}
	emptyIcon="badge"
	emptyTitle="No {term.memberLower} selected"
	emptySub="Select {isEmsDomain ? 'a member' : 'an officer'} from the list to view details"
>
	{#snippet actions()}
		<button class="split-refresh" title="Refresh" onclick={refreshData} disabled={isLoading}>
			<span class="material-icons">{@html ico("refresh")}</span>
		</button>
	{/snippet}

	{#snippet toolbar()}
		<span class="split-select-label">Department</span>
		<SkSelect
			bind:value={departmentFilter}
			options={[
				{ value: "all", label: "All Departments", icon: "account_balance" },
				...departments.map((d) => ({ value: d, label: d.toUpperCase(), icon: "local_police" })),
			]}
		/>
		<div class="split-filters">
			<button class="split-filter" class:active={statusFilter === "all"} onclick={() => (statusFilter = "all")}>All ({officers.length})</button>
			<button class="split-filter" class:active={statusFilter === "on"} onclick={() => (statusFilter = "on")}>On Duty ({activeUnits.length})</button>
		</div>
	{/snippet}

	{#snippet list()}
		{#if filteredOfficers.length === 0}
			<div class="split-none">
				{searchQuery || departmentFilter !== "all" || statusFilter !== "all"
					? `No ${term.membersLower} match your search.`
					: `No ${term.membersLower} are currently in the roster.`}
			</div>
		{:else}
			{#each filteredOfficers as officer (officer.id)}
				<SplitRow
					title="({officer.callsign || '—'}) {officer.firstName} {officer.lastName}"
					subtitle="{deptName(officer)} - {officer.rank}"
					icon="person"
					active={viewedOfficerId === officer.id}
					onclick={() => (viewedOfficerId = officer.id)}
				>
					{#snippet trailing()}
						<span class="duty-dot" class:on={officer.status === "On Duty"} title={officer.status}></span>
					{/snippet}
				</SplitRow>
			{/each}
		{/if}
	{/snippet}

	{#snippet detail()}
		{#if viewedOfficer}
			{@const o = viewedOfficer}
			<div class="cr-pane">
				<div class="cr-actions cr-actions-fill">
					{#if canManageOfficers}
						<button class="cr-btn" onclick={() => openOfficerPanel(o, "callsign")}>Edit</button>
						<button class="cr-btn cr-btn-danger" onclick={() => openOfficerPanel(o, "rank", true)}>Fire</button>
						<button class="cr-btn" onclick={() => openOfficerPanel(o, "rank")}>Rank</button>
					{/if}
					{#if canManageCerts}
						<button class="cr-btn" onclick={() => openOfficerPanel(o, "certs")}>Qualifications</button>
					{/if}
					{#if canManageOfficers}
						<button class="cr-btn" onclick={() => openOfficerPanel(o, "activity")}>History</button>
					{/if}
					<button class="cr-btn cr-close" title="Close" aria-label="Close" onclick={() => (viewedOfficerId = null)}>
						<span class="material-icons">{@html ico("close")}</span>
					</button>
				</div>

				<div class="cr-scroll">
					<div class="roster-detail">
						<div class="roster-col">
							<div class="roster-avatar"><span class="material-icons">{@html ico("person")}</span></div>
							<div class="cr-fields">
								{#if o.citizenid}
									<div class="cr-field">
										<span class="cr-field-label">State ID</span>
										<span class="cr-field-value">
											{o.citizenid}
											<button class="cr-copy" title="Copy State ID" onclick={() => copyText(o.citizenid ?? "")}><span class="material-icons">{@html ico("content_copy")}</span></button>
										</span>
									</div>
								{/if}
								<div class="cr-field">
									<span class="cr-field-label">Name</span>
									<span class="cr-field-value">
										{o.firstName} {o.lastName}
										<button class="cr-copy" title="Copy name" onclick={() => copyText(`${o.firstName} ${o.lastName}`)}><span class="material-icons">{@html ico("content_copy")}</span></button>
									</span>
								</div>
								<div class="cr-field">
									<span class="cr-field-label">Callsign</span>
									<span class="cr-field-value">
										{o.callsign || "—"}
										{#if o.callsign}
											<button class="cr-copy" title="Copy callsign" onclick={() => copyText(o.callsign)}><span class="material-icons">{@html ico("content_copy")}</span></button>
										{/if}
									</span>
								</div>
								{#if o.badgeNumber && o.badgeNumber !== o.callsign}
									<div class="cr-field">
										<span class="cr-field-label">Badge Number</span>
										<span class="cr-field-value">{o.badgeNumber}</span>
									</div>
								{/if}
							</div>
						</div>

						<div class="roster-col">
							<div class="cr-fields">
								<div class="cr-field">
									<span class="cr-field-label">Department</span>
									<span class="cr-field-value">{deptName(o)}</span>
								</div>
								<div class="cr-field">
									<span class="cr-field-label">Rank</span>
									<span class="cr-field-value">{o.rank}</span>
								</div>
								<div class="cr-field">
									<span class="cr-field-label">Status</span>
									<span class="cr-field-value">
										<span class="cr-pill" class:cr-pill-green={o.status === "On Duty"} class:cr-pill-grey={o.status !== "On Duty"}>{o.status}</span>
										{#if o.status === "On Duty" && o.radioChannel && o.radioChannel > 0}
											<span class="cr-pill">Radio {o.radioChannel}</span>
										{/if}
									</span>
								</div>
								<div class="cr-field">
									<span class="cr-field-label">Qualifications ({o.certifications.length})</span>
									{#if o.certifications.length > 0}
										<div class="cr-chips" style="margin-top: 4px;">
											{#each o.certifications as cert}
												<span class="cert-chip" use:tip={getTagDescription(cert)} style="background: {getTagColor(cert)}30; border-color: {getTagColor(cert)}80;">{cert}</span>
											{/each}
										</div>
									{:else}
										<span class="cr-muted">None</span>
									{/if}
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>
		{/if}
	{/snippet}
</SplitView>

<!-- Certification Modal (for users without boss panel access) -->
{#if showCertModal && selectedOfficer}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="modal-overlay" onclick={closeCertModal}>
		<div class="modal-container" onclick={(e) => e.stopPropagation()}>
			<div class="modal-header">
				<div class="modal-title-area">
					<span class="modal-title">Manage Certifications</span>
					<span class="modal-subtitle">{selectedOfficer.firstName} {selectedOfficer.lastName} - {selectedOfficer.callsign}</span>
				</div>
				<button class="modal-close" onclick={closeCertModal}>
					<span class="material-icons">{@html ico("close")}</span>
				</button>
			</div>

			<div class="modal-body">
				{#if availableTags.length === 0}
					<div class="no-tags">
						<span class="material-icons no-tags-icon">{@html ico("label_off")}</span>
						<p>No certifications available.</p>
						<p class="no-tags-hint">Create {term.memberLower} tags in Management &gt; Tags</p>
					</div>
				{:else}
					<div class="cert-grid">
						{#each availableTags as tag (tag.id)}
							<button
								class="cert-option"
								class:selected={selectedCerts.includes(tag.name)}
								onclick={() => toggleCert(tag.name)}
								use:tip={tag.description}
								style="--tag-color: {tag.color}"
							>
								<span class="cert-check">
									{#if selectedCerts.includes(tag.name)}
										<span class="material-icons">{@html ico("check_circle")}</span>
									{:else}
										<span class="material-icons">{@html ico("radio_button_unchecked")}</span>
									{/if}
								</span>
								<span class="cert-color-dot" style="background: {tag.color}"></span>
								<span class="cert-label">{tag.name}</span>
							</button>
						{/each}
					</div>
				{/if}
			</div>

			<div class="modal-footer">
				<button class="btn-cancel" onclick={closeCertModal}>Cancel</button>
				<button
					class="btn-save"
					onclick={saveCertifications}
					disabled={isSavingCerts || availableTags.length === 0}
				>
					{isSavingCerts ? "Saving..." : "Save"}
				</button>
			</div>
		</div>
	</div>
{/if}

<!-- Boss Panel Modal -->
{#if showBossPanel && selectedOfficer}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="modal-overlay" onclick={closeBossPanel}>
		<div class="boss-panel" onclick={(e) => e.stopPropagation()}>
			<div class="modal-header">
				<div class="modal-title-area">
					<span class="modal-title">{term.management}</span>
					<span class="modal-subtitle">{selectedOfficer.firstName} {selectedOfficer.lastName} &bull; {selectedOfficer.callsign} &bull; {selectedOfficer.rank}</span>
				</div>
				<button class="modal-close" onclick={closeBossPanel}>
					<span class="material-icons">{@html ico("close")}</span>
				</button>
			</div>

			<div class="boss-tabs">
				<button class="boss-tab" class:active={bossPanelTab === "rank"} onclick={() => { bossPanelTab = "rank"; showFireConfirm = false; }}>
					<span class="material-icons boss-tab-icon">{@html ico("military_tech")}</span>
					Rank
				</button>
				<button class="boss-tab" class:active={bossPanelTab === "callsign"} onclick={() => { bossPanelTab = "callsign"; showFireConfirm = false; }}>
					<span class="material-icons boss-tab-icon">{@html ico("badge")}</span>
					Callsign
				</button>
				{#if canManageCerts}
					<button class="boss-tab" class:active={bossPanelTab === "certs"} onclick={() => { bossPanelTab = "certs"; showFireConfirm = false; }}>
						<span class="material-icons boss-tab-icon">{@html ico("verified")}</span>
						Certifications
					</button>
				{/if}
				<button class="boss-tab" class:active={bossPanelTab === "ppr"} onclick={() => { bossPanelTab = "ppr"; showFireConfirm = false; loadOfficerPPR(); }}>
					<span class="material-icons boss-tab-icon">{@html ico("rate_review")}</span>
					PPR
				</button>
				<button class="boss-tab" class:active={bossPanelTab === "fto"} onclick={() => { bossPanelTab = "fto"; showFireConfirm = false; loadOfficerFTO(); }}>
					<span class="material-icons boss-tab-icon">{@html ico("school")}</span>
					FTO
				</button>
				<button class="boss-tab" class:active={bossPanelTab === "ia_history"} onclick={() => { bossPanelTab = "ia_history"; showFireConfirm = false; loadIAHistory(); }}>
					<span class="material-icons boss-tab-icon">{@html ico("shield")}</span>
					IA History
				</button>
				<button class="boss-tab" class:active={bossPanelTab === "activity"} onclick={() => { bossPanelTab = "activity"; showFireConfirm = false; }}>
					<span class="material-icons boss-tab-icon">{@html ico("history")}</span>
					Activity
				</button>
			</div>

			<div class="boss-body">
				{#if bossPanelTab === "rank"}
					<div class="boss-section">
						<label class="boss-label">Change Rank</label>
						<p class="boss-hint">Select a new rank for this {term.memberLower}. {term.member} must be online.</p>
						<div class="grade-grid">
							{#if jobGrades.length === 0}
								<div class="no-tags">
									<p>No grades available for this department.</p>
								</div>
							{:else}
								{#each jobGrades as grade (grade.grade)}
									<button
										class="grade-option"
										class:selected={selectedGrade === grade.grade}
										class:current={grade.name === selectedOfficer.rank}
										class:is-boss={grade.isBoss}
										onclick={() => selectedGrade = grade.grade}
									>
										<span class="grade-number">{grade.grade}</span>
										<span class="grade-name">{grade.name}</span>
										{#if grade.name === selectedOfficer.rank}
											<span class="grade-current">Current</span>
										{/if}
										{#if grade.isBoss}
											<span class="grade-boss-badge">Boss</span>
										{/if}
									</button>
								{/each}
							{/if}
						</div>
					</div>

					<div class="boss-divider"></div>

					<div class="boss-section">
						<label class="boss-label boss-label-danger">{term.terminate}</label>
						<p class="boss-hint">{term.removeHint}</p>
						{#if !showFireConfirm}
							<button class="btn-fire" onclick={() => showFireConfirm = true}>
								<span class="material-icons">{@html ico("person_remove")}</span>
								{term.terminate}
							</button>
						{:else}
							<div class="fire-confirm">
								<p class="fire-warning">Are you sure you want to terminate <strong>{selectedOfficer.firstName} {selectedOfficer.lastName}</strong>?</p>
								<label class="fire-delete-toggle">
									<input type="checkbox" bind:checked={deleteUserData} />
									<span>Delete all user data from MDT</span>
								</label>
								{#if deleteUserData}
									<p class="fire-delete-hint">Removes this person's logs, tags, status, FTO/PPR file, clock records and patrol membership. Reports, evidence, cases, warrants and arrests are kept.</p>
								{/if}
								<div class="fire-actions">
									<button class="btn-cancel" onclick={() => showFireConfirm = false}>Cancel</button>
									<button class="btn-fire-confirm" onclick={fireOfficer} disabled={isSavingBoss}>
										{isSavingBoss ? "Processing..." : "Confirm Termination"}
									</button>
								</div>
							</div>
						{/if}
					</div>

				{:else if bossPanelTab === "callsign"}
					<div class="boss-section">
						<label class="boss-label">Edit Callsign</label>
						<p class="boss-hint">Update this {term.memberLower}'s callsign/badge number. {term.member} must be online.</p>
						<div class="callsign-input-row">
							<input
								type="text"
								class="callsign-input"
								bind:value={editCallsign}
								placeholder="Enter callsign..."
								maxlength="10"
							/>
						</div>
					</div>

				{:else if bossPanelTab === "certs"}
					<div class="boss-section">
						<label class="boss-label">Manage Certifications</label>
						{#if availableTags.length === 0}
							<div class="no-tags">
								<span class="material-icons no-tags-icon">{@html ico("label_off")}</span>
								<p>No certifications available.</p>
								<p class="no-tags-hint">Create {term.memberLower} tags in Management &gt; Tags</p>
							</div>
						{:else}
							<div class="cert-grid">
								{#each availableTags as tag (tag.id)}
									<button
										class="cert-option"
										class:selected={selectedCerts.includes(tag.name)}
										onclick={() => toggleCert(tag.name)}
										use:tip={tag.description}
										style="--tag-color: {tag.color}"
									>
										<span class="cert-check">
											{#if selectedCerts.includes(tag.name)}
												<span class="material-icons">{@html ico("check_circle")}</span>
											{:else}
												<span class="material-icons">{@html ico("radio_button_unchecked")}</span>
											{/if}
										</span>
										<span class="cert-color-dot" style="background: {tag.color}"></span>
										<span class="cert-label">{tag.name}</span>
									</button>
								{/each}
							</div>
						{/if}
					</div>

				{:else if bossPanelTab === "ppr"}
					<div class="boss-section">
						<label class="boss-label">Performance Reviews</label>
						<p class="boss-hint">Performance planning and review entries for this {term.memberLower}.</p>
						{#if pprHistoryLoading}
							<p class="boss-hint">Loading...</p>
						{:else if pprHistory.length === 0}
							<div class="no-tags">
								<span class="material-icons no-tags-icon">{@html ico("rate_review")}</span>
								<p>No PPR entries found for this {term.memberLower}.</p>
							</div>
						{:else}
							<div class="ia-history-list">
								{#each pprHistory as ppr}
									<div class="ia-history-item">
										<div class="ia-history-info">
											<span class="ia-history-number">{ppr.ppr_number}</span>
											<span class="ia-pill {getPPRCategoryClass(ppr.category)}">{formatPPRCategory(ppr.category)}</span>
										</div>
										<div class="ia-history-meta">
											<span style="flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">{ppr.title}</span>
											<span class="ia-history-date">{formatDateShort(ppr.created_at)}</span>
										</div>
										<div class="ia-history-meta">
											<span style="color: rgba(255,255,255,0.35); font-size: 9px;">By {ppr.author_name}</span>
										</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>

				{:else if bossPanelTab === "fto"}
					<div class="boss-section">
						<label class="boss-label">Field Training History</label>
						<p class="boss-hint">FTO training assignments for this {term.memberLower}.</p>
						{#if ftoHistoryLoading}
							<p class="boss-hint">Loading...</p>
						{:else if ftoHistory.length === 0}
							<div class="no-tags">
								<span class="material-icons no-tags-icon">{@html ico("school")}</span>
								<p>No FTO records found for this {term.memberLower}.</p>
							</div>
						{:else}
							<div class="ia-history-list">
								{#each ftoHistory as record}
									<div class="ia-history-item">
										<div class="ia-history-info">
											<span class="ia-history-number">{record.fto_number}</span>
											<span class="ia-pill {getFTOStatusClass(record.status)}">{record.status.toUpperCase()}</span>
										</div>
										<div class="ia-history-meta">
											<span style="flex:1;">
												{record.trainee_name === selectedOfficer?.name ? 'Trainer' : 'Trainee'}:
												{record.trainee_name === selectedOfficer?.name ? record.trainer_name : record.trainee_name}
											</span>
											{#if record.phase_name}
												<span style="color: rgba(255,255,255,0.5); font-size: 9px;">{record.phase_name}</span>
											{/if}
										</div>
										<div class="ia-history-meta">
											{#if record.dor_count}
												<span style="color: rgba(255,255,255,0.35); font-size: 9px;">{record.dor_count} DOR{record.dor_count !== 1 ? 's' : ''}</span>
											{/if}
											{#if record.latest_rating}
												<span style="color: rgba(255,255,255,0.5); font-size: 9px;">Rating: {record.latest_rating}/5</span>
											{/if}
											<span class="ia-history-date">{formatDateShort(record.start_date || record.created_at)}</span>
										</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>

				{:else if bossPanelTab === "ia_history"}
					<div class="boss-section">
						<label class="boss-label">IA Complaint History</label>
						<p class="boss-hint">Internal affairs complaints involving this {term.memberLower}.</p>
						{#if iaHistoryLoading}
							<p class="boss-hint">Loading...</p>
						{:else if iaHistory.length === 0}
							<div class="no-tags">
								<span class="material-icons no-tags-icon">{@html ico("verified_user")}</span>
								<p>No IA complaints found for this {term.memberLower}.</p>
							</div>
						{:else}
							<div class="ia-history-list">
								{#each iaHistory as complaint}
									<div class="ia-history-item">
										<div class="ia-history-info">
											<span class="ia-history-number">{complaint.complaint_number}</span>
											<span class="ia-pill {getIAStatusClass(complaint.status)}">{formatIAStatus(complaint.status)}</span>
										</div>
										<div class="ia-history-meta">
											<span>{formatIAStatus(complaint.category)}</span>
											<span class="ia-history-date">{complaint.created_at ? formatDate(complaint.created_at) : '-'}</span>
										</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>

				{:else if bossPanelTab === "activity"}
					<div class="boss-section">
						<label class="boss-label">Activity Timeline</label>
						<p class="boss-hint">Recorded changes involving this {term.memberLower} — rank, callsign, status and more.</p>
						{#if selectedOfficer?.citizenid}
							<ActivityTimeline citizenid={selectedOfficer.citizenid} />
						{/if}
					</div>
				{/if}
			</div>

			<div class="modal-footer">
				<button class="btn-cancel" onclick={closeBossPanel}>Close</button>
				{#if bossPanelTab === "rank" && selectedGrade !== null}
					<button
						class="btn-save"
						onclick={promoteOfficer}
						disabled={isSavingBoss}
					>
						{isSavingBoss ? "Saving..." : "Update Rank"}
					</button>
				{:else if bossPanelTab === "callsign"}
					<button
						class="btn-save"
						onclick={saveCallsign}
						disabled={isSavingBoss || editCallsign.length === 0}
					>
						{isSavingBoss ? "Saving..." : "Save Callsign"}
					</button>
				{:else if bossPanelTab === "certs"}
					<button
						class="btn-save"
						onclick={saveCertifications}
						disabled={isSavingCerts || availableTags.length === 0}
					>
						{isSavingCerts ? "Saving..." : "Save Certifications"}
					</button>
				{/if}
			</div>
		</div>
	</div>
{/if}

<style>
	/* ===== SPLIT VIEW DETAIL ===== */
	.duty-dot { width: 9px; height: 9px; border-radius: 50%; background: rgba(255, 255, 255, 0.2); }
	.duty-dot.on { background: #22c55e; box-shadow: 0 0 6px rgba(34, 197, 94, 0.6); }
	.roster-detail { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; padding-top: 4px; }
	.roster-col { display: flex; flex-direction: column; min-width: 0; }
	.roster-avatar { width: 220px; height: 220px; max-width: 100%; aspect-ratio: 1; align-self: center; border-radius: 50%; display: flex; align-items: center; justify-content: center; background: #05070d; border: 2px solid rgba(255, 255, 255, 0.08); margin-bottom: 18px; }
	.roster-avatar .material-icons { font-size: 110px; color: #fff; }
	.cert-chip { padding: 3px 8px; border-radius: 4px; border: 1px solid; font-size: 12px; font-weight: 700; color: #fff; }

	.roster-page {
		display: flex;
		flex-direction: column;
		height: 100%;
		background: var(--card-dark-bg);
		color: rgba(255, 255, 255, 0.9);
		overflow: hidden;
	}

	.topbar {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 0 16px;
		height: 42px;
		flex-shrink: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.search-input {
		flex: 1;
		max-width: 360px;
		background: transparent;
		border: none;
		padding: 0;
		color: rgba(255, 255, 255, 0.8);
		font-size: 12px;
	}

	.search-input:focus {
		outline: none;
	}

	.search-input::placeholder {
		color: rgba(255, 255, 255, 0.2);
	}

	.topbar-right {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-left: auto;
	}

	.result-count {
		color: rgba(255, 255, 255, 0.2);
		font-size: 10px;
	}

	.btn-secondary {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 10px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-secondary:hover:not(:disabled) {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.btn-secondary:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.content-area {
		display: grid;
		grid-template-columns: 1fr 180px;
		gap: 0;
		flex: 1;
		min-height: 0;
		overflow: hidden;
	}

	.list-panel {
		background: transparent;
		border: none;
		border-radius: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
		border-right: 1px solid rgba(255, 255, 255, 0.06);
	}

	.table-header {
		display: grid;
		grid-template-columns: 80px 70px 1.2fr 70px 1fr 0.8fr 1.5fr;
		gap: 8px;
		padding: 8px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.col-header {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.35);
		background: none;
		border: none;
		padding: 0;
		text-align: left;
		cursor: default;
	}

	.col-header.sortable {
		cursor: pointer;
	}

	.col-header.sortable:hover {
		color: rgba(255, 255, 255, 0.5);
	}

	.table-body {
		flex: 1;
		overflow-y: auto;
	}

	.table-row {
		display: grid;
		grid-template-columns: 80px 70px 1.2fr 70px 1fr 0.8fr 1.5fr;
		gap: 8px;
		padding: 7px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		font-size: 11px;
		align-items: center;
		transition: background 0.1s;
	}

	.table-row:hover {
		background: rgba(255, 255, 255, 0.02);
	}

	.table-row.clickable {
		cursor: pointer;
	}

	.table-row.clickable:hover {
		background: rgba(255, 255, 255, 0.03);
	}

	.table-row:last-child {
		border-bottom: none;
	}

	.cell-callsign {
		font-family: var(--font-main);
		font-size: 10px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-weight: 500;
	}

	.cell-name {
		font-weight: 500;
		font-size: 11px;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.cell-rank {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.cell-dept {
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	.cell-radio {
		font-size: 10px;
	}

	.radio-badge {
		display: inline-block;
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
		font-family: var(--font-main);
		background: rgba(var(--accent-rgb), 0.08);
		color: rgba(var(--accent-text-rgb), 0.7);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
	}

	.cell-muted {
		color: rgba(255, 255, 255, 0.1);
	}

	.status-pill {
		display: inline-block;
		padding: 1px 6px;
		border-radius: 3px;
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}

	.status-pill.on-duty {
		background: rgba(16, 185, 129, 0.08);
		color: rgba(110, 231, 183, 0.8);
		border: 1px solid rgba(16, 185, 129, 0.1);
	}

	.status-pill.off-duty {
		background: rgba(255, 255, 255, 0.03);
		color: rgba(255, 255, 255, 0.3);
		border: 1px solid rgba(255, 255, 255, 0.05);
	}

	.cell-certs {
		display: flex;
		flex-wrap: wrap;
		gap: 3px;
	}

	.cert-tag {
		padding: 1px 5px;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 3px;
		font-size: 9px;
	}

	/* Active Units Sidebar */
	.units-panel {
		background: transparent;
		border: none;
		border-radius: 0;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.units-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 8px 14px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.units-label {
		font-size: 9px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.6px;
		color: rgba(255, 255, 255, 0.35);
	}

	.units-count {
		font-size: 10px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.35);
		background: rgba(255, 255, 255, 0.03);
		padding: 1px 6px;
		border-radius: 3px;
	}

	.units-list {
		flex: 1;
		overflow-y: auto;
	}

	.unit-row {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 6px 14px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		font-size: 11px;
	}

	.unit-row:last-child {
		border-bottom: none;
	}

	.unit-callsign {
		font-family: var(--font-main);
		font-size: 10px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-weight: 500;
		min-width: 28px;
	}

	.unit-name {
		color: rgba(255, 255, 255, 0.5);
		font-size: 11px;
	}

	.units-empty {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 80px;
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
	}

	/* States */
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		height: 200px;
		text-align: center;
		color: rgba(255, 255, 255, 0.35);
	}

	.empty-title {
		font-size: 14px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.4);
		margin: 0 0 4px;
	}

	.empty-sub {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.35);
		margin: 0;
	}

	.loading-spinner {
		width: 24px;
		height: 24px;
		border: 2px solid rgba(255, 255, 255, 0.06);
		border-left: 2px solid rgba(var(--accent-rgb), 0.5);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
		margin-bottom: 10px;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	/* Scrollbars */
	.table-body::-webkit-scrollbar,
	.units-list::-webkit-scrollbar {
		width: 4px;
	}

	.table-body::-webkit-scrollbar-track,
	.units-list::-webkit-scrollbar-track {
		background: transparent;
	}

	.table-body::-webkit-scrollbar-thumb,
	.units-list::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.06);
		border-radius: 2px;
	}

	/* Certification Modal */
	.modal-overlay {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: rgba(0, 0, 0, 0.6);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
	}

	.modal-container {
		background: var(--card-dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		width: 400px;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.modal-title-area {
		display: flex;
		flex-direction: column;
		gap: 1px;
	}

	.modal-title {
		font-size: 12px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.85);
	}

	.modal-subtitle {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.3);
	}

	.modal-close {
		background: none;
		border: none;
		color: rgba(255, 255, 255, 0.3);
		cursor: pointer;
		padding: 4px;
		border-radius: 3px;
		transition: all 0.1s;
		display: flex;
		align-items: center;
	}

	.modal-close:hover {
		color: rgba(255, 255, 255, 0.7);
		background: rgba(255, 255, 255, 0.04);
	}

	.modal-close .material-icons {
		font-size: 16px;
	}

	.modal-body {
		padding: 12px 16px;
		overflow-y: auto;
		flex: 1;
	}

	.no-tags {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 24px 0;
		color: rgba(255, 255, 255, 0.3);
		text-align: center;
	}

	.no-tags-icon {
		font-size: 28px;
		margin-bottom: 8px;
		color: rgba(255, 255, 255, 0.1);
	}

	.no-tags p {
		margin: 0;
		font-size: 11px;
	}

	.no-tags-hint {
		font-size: 10px !important;
		color: rgba(255, 255, 255, 0.2) !important;
		margin-top: 4px !important;
	}

	.cert-grid {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.cert-option {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 7px 10px;
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 3px;
		cursor: pointer;
		transition: all 0.1s;
		color: rgba(255, 255, 255, 0.6);
		font-size: 11px;
	}

	.cert-option:hover {
		background: rgba(255, 255, 255, 0.03);
		border-color: rgba(255, 255, 255, 0.08);
	}

	.cert-option.selected {
		background: color-mix(in srgb, var(--tag-color) 6%, transparent);
		border-color: color-mix(in srgb, var(--tag-color) 20%, transparent);
		color: rgba(255, 255, 255, 0.85);
	}

	.cert-check {
		display: flex;
		align-items: center;
		flex-shrink: 0;
	}

	.cert-check .material-icons {
		font-size: 16px;
		color: rgba(255, 255, 255, 0.15);
	}

	.cert-option.selected .cert-check .material-icons {
		color: var(--tag-color);
	}

	.cert-color-dot {
		width: 6px;
		height: 6px;
		border-radius: 50%;
		flex-shrink: 0;
	}

	.cert-label {
		font-weight: 500;
	}

	.modal-footer {
		display: flex;
		justify-content: flex-end;
		gap: 6px;
		padding: 10px 16px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}

	.btn-cancel {
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 3px;
		padding: 4px 12px;
		color: rgba(255, 255, 255, 0.4);
		font-size: 10px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-cancel:hover {
		color: rgba(255, 255, 255, 0.7);
		border-color: rgba(255, 255, 255, 0.1);
	}

	.btn-save {
		background: rgba(var(--accent-rgb), 0.06);
		border: 1px solid rgba(var(--accent-rgb), 0.1);
		border-radius: 3px;
		padding: 5px 16px;
		color: rgba(var(--accent-text-rgb), 0.7);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-save:hover:not(:disabled) {
		background: rgba(var(--accent-rgb), 0.12);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.btn-save:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	/* Boss Panel */
	.boss-panel {
		background: var(--card-dark-bg);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 6px;
		width: 600px;
		max-width: 92vw;
		max-height: 80vh;
		display: flex;
		flex-direction: column;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
	}

	.boss-tabs {
		display: flex;
		flex-wrap: wrap;
		gap: 0;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		padding: 0 16px;
	}

	.boss-tab {
		display: flex;
		align-items: center;
		gap: 4px;
		padding: 8px 10px;
		background: none;
		border: none;
		border-bottom: 2px solid transparent;
		color: rgba(255, 255, 255, 0.35);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
		text-transform: uppercase;
		letter-spacing: 0.3px;
		white-space: nowrap;
	}

	.boss-tab:hover {
		color: rgba(255, 255, 255, 0.6);
	}

	.boss-tab.active {
		color: rgba(var(--accent-text-rgb), 0.85);
		border-bottom-color: rgba(var(--accent-rgb), 0.5);
	}

	.boss-tab-icon {
		font-size: 14px;
	}

	.boss-body {
		padding: 14px 16px;
		overflow-y: auto;
		flex: 1;
	}

	.boss-section {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.boss-label {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.7);
	}

	.boss-label-danger {
		color: rgba(239, 68, 68, 0.8);
	}

	.boss-hint {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.25);
		margin: 0 0 6px;
		line-height: 1.4;
	}

	.boss-divider {
		height: 1px;
		background: rgba(255, 255, 255, 0.06);
		margin: 14px 0;
	}

	/* Grade Grid */
	.grade-grid {
		display: flex;
		flex-direction: column;
		gap: 3px;
	}

	.grade-option {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 7px 10px;
		background: transparent;
		border: 1px solid rgba(255, 255, 255, 0.05);
		border-radius: 3px;
		cursor: pointer;
		transition: all 0.1s;
		color: rgba(255, 255, 255, 0.6);
		font-size: 11px;
		text-align: left;
	}

	.grade-option:hover {
		background: rgba(255, 255, 255, 0.03);
		border-color: rgba(255, 255, 255, 0.08);
	}

	.grade-option.selected {
		background: rgba(var(--accent-rgb), 0.08);
		border-color: rgba(var(--accent-rgb), 0.2);
		color: rgba(var(--accent-text-rgb), 0.9);
	}

	.grade-option.current {
		border-color: rgba(16, 185, 129, 0.15);
	}

	.grade-number {
		font-family: var(--font-main);
		font-size: 9px;
		color: rgba(255, 255, 255, 0.2);
		min-width: 16px;
		text-align: center;
	}

	.grade-option.selected .grade-number {
		color: rgba(var(--accent-text-rgb), 0.5);
	}

	.grade-name {
		font-weight: 500;
		flex: 1;
	}

	.grade-current {
		font-size: 8px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(16, 185, 129, 0.7);
		font-weight: 600;
	}

	.grade-boss-badge {
		font-size: 8px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
		color: rgba(251, 191, 36, 0.7);
		font-weight: 600;
		background: rgba(251, 191, 36, 0.08);
		padding: 1px 5px;
		border-radius: 2px;
	}

	/* Callsign Input */
	.callsign-input-row {
		display: flex;
		gap: 8px;
	}

	.callsign-input {
		flex: 1;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 3px;
		padding: 7px 10px;
		color: rgba(255, 255, 255, 0.85);
		font-size: 12px;
		font-family: var(--font-main);
	}

	.callsign-input:focus {
		outline: none;
		border-color: rgba(var(--accent-rgb), 0.3);
	}

	.callsign-input::placeholder {
		color: rgba(255, 255, 255, 0.15);
	}

	/* Fire Button */
	.btn-fire {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 6px 14px;
		background: rgba(239, 68, 68, 0.06);
		border: 1px solid rgba(239, 68, 68, 0.12);
		border-radius: 3px;
		color: rgba(239, 68, 68, 0.7);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
		width: fit-content;
	}

	.btn-fire .material-icons {
		font-size: 14px;
	}

	.btn-fire:hover {
		background: rgba(239, 68, 68, 0.12);
		color: rgba(239, 68, 68, 0.9);
		border-color: rgba(239, 68, 68, 0.2);
	}

	.fire-confirm {
		background: rgba(239, 68, 68, 0.04);
		border: 1px solid rgba(239, 68, 68, 0.1);
		border-radius: 4px;
		padding: 10px 12px;
	}

	.fire-warning {
		font-size: 11px;
		color: rgba(255, 255, 255, 0.6);
		margin: 0 0 10px;
		line-height: 1.4;
	}

	.fire-warning strong {
		color: rgba(255, 255, 255, 0.85);
	}

	.fire-delete-toggle {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 12px;
		color: rgba(255, 255, 255, 0.85);
		cursor: pointer;
		margin: 0 0 8px;
		user-select: none;
	}

	.fire-delete-toggle input {
		accent-color: #ef4444;
		cursor: pointer;
	}

	.fire-delete-hint {
		font-size: 10px;
		color: rgba(255, 255, 255, 0.5);
		margin: 0 0 10px;
		line-height: 1.4;
	}

	.fire-actions {
		display: flex;
		gap: 6px;
		justify-content: flex-end;
	}

	.btn-fire-confirm {
		background: rgba(239, 68, 68, 0.15);
		border: 1px solid rgba(239, 68, 68, 0.25);
		border-radius: 3px;
		padding: 4px 12px;
		color: rgba(239, 68, 68, 0.9);
		font-size: 10px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.1s;
	}

	.btn-fire-confirm:hover:not(:disabled) {
		background: rgba(239, 68, 68, 0.25);
	}

	.btn-fire-confirm:disabled {
		opacity: 0.4;
		cursor: not-allowed;
	}

	.ia-history-list {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.ia-history-item {
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 6px;
		padding: 8px 10px;
	}
	.ia-history-info {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-bottom: 3px;
	}
	.ia-history-number {
		font-size: 11px;
		font-weight: 600;
		color: rgba(255, 255, 255, 0.87);
	}
	.ia-history-meta {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 10px;
		color: rgba(255, 255, 255, 0.4);
	}
	.ia-history-date {
		margin-left: auto;
	}
	.ia-pill {
		font-size: 9px;
		padding: 1px 6px;
		border-radius: 3px;
		font-weight: 600;
		text-transform: uppercase;
		letter-spacing: 0.3px;
	}
	.pill-blue { background: rgba(var(--accent-rgb), 0.2); color: var(--accent-text); }
	.pill-orange { background: rgba(245, 158, 11, 0.2); color: rgb(253, 224, 71); }
	.pill-yellow { background: rgba(234, 179, 8, 0.2); color: rgb(253, 224, 71); }
	.pill-red { background: rgba(239, 68, 68, 0.2); color: rgb(252, 165, 165); }
	.pill-green { background: rgba(16, 185, 129, 0.2); color: rgb(167, 243, 208); }
	.pill-gray { background: rgba(107, 114, 128, 0.2); color: rgb(156, 163, 175); }
	.status-active { background: rgba(var(--accent-rgb), 0.2); color: var(--accent-text); }
	.status-completed { background: rgba(16, 185, 129, 0.2); color: rgb(167, 243, 208); }
	.status-failed { background: rgba(239, 68, 68, 0.2); color: rgb(252, 165, 165); }
	.status-suspended { background: rgba(245, 158, 11, 0.2); color: rgb(253, 224, 71); }


</style>