<script lang="ts">
	import { ico } from "@/icons";

	// Skewed dropdown. Replaces a native <select> where the open list needs to
	// match the MDT styling (the browser draws native option lists itself).
	interface Option {
		value: string;
		label: string;
		icon?: string;
	}

	interface Props {
		value: string;
		options: Option[];
		placeholder?: string;
		onchange?: (value: string) => void;
	}

	let { value = $bindable(""), options, placeholder = "Select...", onchange }: Props = $props();

	let open = $state(false);
	let highlighted = $state(-1);
	let root: HTMLDivElement | undefined = $state();

	let selected = $derived(options.find((o) => o.value === value));

	function toggle() {
		open = !open;
		if (open) highlighted = Math.max(0, options.findIndex((o) => o.value === value));
	}

	function choose(opt: Option) {
		value = opt.value;
		open = false;
		onchange?.(opt.value);
	}

	function onKeydown(e: KeyboardEvent) {
		if (!open && (e.key === "ArrowDown" || e.key === "Enter" || e.key === " ")) {
			e.preventDefault();
			toggle();
			return;
		}
		if (!open) return;
		if (e.key === "Escape") {
			e.preventDefault();
			e.stopPropagation();
			open = false;
		} else if (e.key === "ArrowDown") {
			e.preventDefault();
			highlighted = (highlighted + 1) % options.length;
		} else if (e.key === "ArrowUp") {
			e.preventDefault();
			highlighted = (highlighted - 1 + options.length) % options.length;
		} else if (e.key === "Enter") {
			e.preventDefault();
			if (options[highlighted]) choose(options[highlighted]);
		}
	}

	$effect(() => {
		if (!open) return;
		const onDown = (e: PointerEvent) => {
			if (root && !root.contains(e.target as Node)) open = false;
		};
		window.addEventListener("pointerdown", onDown);
		return () => window.removeEventListener("pointerdown", onDown);
	});
</script>

<div class="sk-select" class:open bind:this={root}>
	<button type="button" class="sk-select-trigger" aria-haspopup="listbox" aria-expanded={open} onclick={toggle} onkeydown={onKeydown}>
		{#if selected?.icon}<span class="material-icons sk-select-icon">{@html ico(selected.icon)}</span>{/if}
		<span class="sk-select-label" class:placeholder={!selected}>{selected?.label ?? placeholder}</span>
		<span class="material-icons sk-select-chevron">{@html ico("expand_more")}</span>
	</button>

	{#if open}
		<div class="sk-select-menu" role="listbox">
			{#each options as opt, i (opt.value)}
				<button
					type="button"
					class="sk-select-option"
					class:active={opt.value === value}
					class:hl={i === highlighted}
					role="option"
					aria-selected={opt.value === value}
					onclick={() => choose(opt)}
					onpointerenter={() => (highlighted = i)}
				>
					{#if opt.icon}<span class="material-icons sk-select-icon">{@html ico(opt.icon)}</span>{/if}
					<span class="sk-select-option-label">{opt.label}</span>
					{#if opt.value === value}<span class="material-icons sk-select-check">{@html ico("check")}</span>{/if}
				</button>
			{/each}
		</div>
	{/if}
</div>

<style>
	.sk-select { position: relative; width: 100%; }

	.sk-select-trigger { position: relative; isolation: isolate; display: flex; align-items: center; gap: 8px; width: 100%; height: 38px; padding: 0 14px; background: none; border: none; color: #fff; font-size: 13px; font-weight: 600; text-align: left; cursor: pointer; }
	.sk-select-trigger::before { content: ""; position: absolute; inset: 0; clip-path: var(--chamfer); background: var(--dark-bg); border: 1px solid var(--border-secondary); border-radius: 3px; z-index: -1; transition: border-color 0.12s, box-shadow 0.12s; }
	.sk-select-trigger:hover::before { border-color: var(--border-hover); }
	.sk-select.open .sk-select-trigger::before,
	.sk-select-trigger:focus-visible::before { border-color: var(--accent); box-shadow: 0 0 0 1px rgba(var(--accent-rgb), 0.35); }
	.sk-select-trigger:focus-visible { outline: none; }

	.sk-select-label { flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.sk-select-label.placeholder { color: var(--secondary-text); }
	.sk-select-icon { font-size: 17px; color: var(--accent); }
	.sk-select-chevron { font-size: 18px; color: var(--secondary-text); transition: transform 0.15s; }
	.sk-select.open .sk-select-chevron { transform: rotate(180deg); color: #fff; }

	.sk-select-menu { position: absolute; top: calc(100% + 6px); left: 0; right: 0; z-index: 60; max-height: 280px; overflow-y: auto; padding: 6px; background: var(--menu-bg); border: 1px solid var(--border-secondary); border-left: 3px solid var(--accent); border-radius: 4px; box-shadow: 0 16px 40px rgba(0, 0, 0, 0.55); animation: sk-select-in 0.12s ease-out; }

	.sk-select-option { position: relative; isolation: isolate; display: flex; align-items: center; gap: 10px; width: 100%; height: 34px; padding: 0 14px; background: none; border: none; color: var(--primary-text); font-size: 13px; font-weight: 600; text-align: left; cursor: pointer; }
	.sk-select-option::before { content: ""; position: absolute; inset: 2px 6px; clip-path: var(--chamfer); border-radius: 2px; z-index: -1; transition: background 0.1s; }
	.sk-select-option.hl::before { background: rgba(255, 255, 255, 0.07); }
	.sk-select-option.active { color: #fff; }
	.sk-select-option.active::before { background: rgba(var(--accent-rgb), 0.22); box-shadow: inset 0 0 0 1px rgba(var(--accent-rgb), 0.5); }
	.sk-select-option-label { flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.sk-select-check { font-size: 16px; color: var(--accent-text); }

	@keyframes sk-select-in {
		from { transform: translateY(-4px); }
		to { transform: translateY(0); }
	}
</style>
