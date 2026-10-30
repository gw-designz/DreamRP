<script lang="ts">
	import { ico } from "@/icons";
	import type { Snippet } from "svelte";

	// CircuitRP-style record browser: search + results on the left,
	// the selected record (or an empty state) on the right.
	interface Props {
		query: string;
		placeholder?: string;
		loading?: boolean;
		loadingText?: string;
		/** Show a "search for ..." prompt instead of the list until the user types */
		requireQuery?: boolean;
		promptIcon?: string;
		promptTitle?: string;
		promptSub?: string;
		hasSelection?: boolean;
		emptyIcon?: string;
		emptyTitle?: string;
		emptySub?: string;
		/** Buttons beside the search box (e.g. Hire, Add) */
		actions?: Snippet;
		/** Controls under the search box (filters, dropdowns) */
		toolbar?: Snippet;
		list: Snippet;
		/** Pinned under the list (pagination) */
		footer?: Snippet;
		detail?: Snippet;
		/** Left list folded down to a thin strip (bindable) */
		collapsed?: boolean;
	}

	let {
		query = $bindable(""),
		placeholder = "Search...",
		loading = false,
		loadingText = "Loading...",
		requireQuery = false,
		promptIcon = "search",
		promptTitle = "Search",
		promptSub = "Press / from anywhere to jump here.",
		hasSelection = false,
		emptyIcon = "inbox",
		emptyTitle = "Nothing selected",
		emptySub = "Select an item from the list to view details",
		actions,
		toolbar,
		list,
		footer,
		detail,
		collapsed = $bindable(false),
	}: Props = $props();

	let searchInput: HTMLInputElement | undefined = $state();

	function focusSearch() {
		collapsed = false;
		requestAnimationFrame(() => searchInput?.focus());
	}

	// Press "/" anywhere (outside a text field) to jump to the search box
	$effect(() => {
		const onKey = (e: KeyboardEvent) => {
			if (e.key !== "/") return;
			const el = document.activeElement as HTMLElement | null;
			if (el && (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.tagName === "SELECT" || el.isContentEditable)) return;
			e.preventDefault();
			focusSearch();
		};
		window.addEventListener("keydown", onKey);
		return () => window.removeEventListener("keydown", onKey);
	});
</script>

<div class="split-page">
	<aside class="split-list" class:collapsed>
		{#if collapsed}
			<button class="split-collapse" title="Show search" onclick={() => (collapsed = false)}>
				<span class="material-icons">{@html ico("chevron_right")}</span>
			</button>
		{:else}
			<div class="split-search-row">
				<div class="split-search">
					<span class="material-icons split-search-icon">{@html ico("search")}</span>
					<input bind:this={searchInput} bind:value={query} type="text" {placeholder} />
					{#if query}
						<button class="split-clear" title="Clear" onclick={() => { query = ""; focusSearch(); }}>
							<span class="material-icons">{@html ico("close")}</span>
						</button>
					{/if}
				</div>
				{#if actions}
					{@render actions()}
				{:else}
					<button class="split-refresh" title="Search" onclick={focusSearch}>
						<span class="material-icons">{@html ico("search")}</span>
					</button>
				{/if}
				<button class="split-collapse" title="Hide search" onclick={() => (collapsed = true)}>
					<span class="material-icons">{@html ico("chevron_left")}</span>
				</button>
			</div>

			{#if toolbar}
				<div class="split-toolbar">{@render toolbar()}</div>
			{/if}

			<div class="split-results">
				{#if loading}
					<div class="split-prompt"><div class="split-spinner"></div><span class="split-prompt-sub">{loadingText}</span></div>
				{:else if requireQuery && !query.trim()}
					<div class="split-prompt">
						<span class="material-icons split-prompt-icon">{@html ico(promptIcon)}</span>
						<span class="split-prompt-title">{promptTitle}</span>
						<span class="split-prompt-sub">{promptSub}</span>
					</div>
				{:else}
					{@render list()}
				{/if}
			</div>

			{#if footer && !loading}
				<div class="split-footer">{@render footer()}</div>
			{/if}
		{/if}
	</aside>

	<section class="split-detail">
		{#if hasSelection && detail}
			{@render detail()}
		{:else}
			<div class="split-empty">
				<span class="material-icons split-empty-icon">{@html ico(emptyIcon)}</span>
				<span class="split-empty-title">{emptyTitle}</span>
				<span class="split-empty-sub">{emptySub}</span>
			</div>
		{/if}
	</section>
</div>

<style>
	.split-page { height: 100%; display: flex; gap: 8px; padding: 8px; background: var(--dark-bg); overflow: hidden; }

	.split-list { width: 38%; min-width: 320px; max-width: 560px; display: flex; flex-direction: column; background: var(--card-dark-bg); border: 1px solid var(--border-primary); border-radius: 4px; overflow: hidden; flex-shrink: 0; }
	.split-list.collapsed { width: auto; min-width: 0; padding: 10px 6px; align-items: center; }

	.split-search-row { display: flex; align-items: center; gap: 8px; padding: 10px 12px; flex-shrink: 0; }
	/* Skewed field: the slanted box is drawn on ::before so the text stays upright */
	.split-search { flex: 1; min-width: 0; display: flex; align-items: center; gap: 8px; height: 38px; padding: 0 14px; position: relative; isolation: isolate; }
	.split-search::before { content: ""; position: absolute; inset: 0; clip-path: var(--chamfer); background: var(--dark-bg); border: 1px solid var(--border-secondary); border-radius: 3px; z-index: -1; transition: border-color 0.12s, box-shadow 0.12s; }
	.split-search:focus-within::before { border-color: var(--accent); box-shadow: 0 0 0 1px rgba(var(--accent-rgb), 0.35); }
	.split-search input { flex: 1; min-width: 0; background: none; border: none; outline: none; color: #fff; font-size: 14px; font-weight: 500; }
	.split-search input::placeholder { color: var(--secondary-text); }
	.split-search-icon { font-size: 20px; color: #fff; }
	.split-clear { display: flex; background: none; border: none; color: #fff; cursor: pointer; padding: 2px; border-radius: 3px; }
	.split-clear .material-icons { font-size: 18px; }
	.split-clear:hover { background: var(--hover-bg); }


	.split-collapse { width: 28px; height: 38px; display: flex; align-items: center; justify-content: center; background: none; border: none; color: #fff; cursor: pointer; border-radius: 4px; flex-shrink: 0; }
	.split-collapse:hover { background: var(--hover-bg); }
	.split-collapse .material-icons { font-size: 22px; }

	.split-toolbar { display: flex; flex-direction: column; gap: 8px; padding: 0 12px 10px; flex-shrink: 0; }

	.split-results { flex: 1; min-height: 0; overflow-y: auto; display: flex; flex-direction: column; padding: 0 12px 10px; }
	.split-footer { flex-shrink: 0; border-top: 1px solid var(--border-primary); }

	.split-prompt { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; text-align: center; padding: 0 40px; }
	.split-prompt-icon { font-size: 40px; color: var(--secondary-text); margin-bottom: 6px; }
	.split-prompt-title { font-size: 15px; font-weight: 600; color: #fff; }
	.split-prompt-sub { font-size: 12px; font-weight: 500; color: var(--primary-text); max-width: 280px; line-height: 1.45; }
	.split-spinner { width: 24px; height: 24px; border: 2px solid rgba(255,255,255,0.08); border-top-color: var(--accent); border-radius: 50%; animation: split-spin 0.8s linear infinite; margin-bottom: 8px; }
	@keyframes split-spin { to { transform: rotate(360deg); } }

	.split-detail { flex: 1; min-width: 0; display: flex; flex-direction: column; background: var(--card-dark-bg); border: 1px solid var(--border-primary); border-radius: 4px; overflow: hidden; position: relative; }

	.split-empty { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; text-align: center; padding: 0 24px; }
	.split-empty-icon { font-size: 96px; line-height: 1; color: rgba(var(--accent-rgb), 0.55); }
	.split-empty-title { font-size: 26px; font-weight: 700; color: #fff; }
	.split-empty-sub { font-size: 16px; font-weight: 500; color: var(--primary-text); }
</style>
