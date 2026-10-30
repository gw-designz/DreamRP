<script lang="ts">
    import {onMount} from "svelte";
    import {useNuiEvent} from "@/utils/useNuiEvent";
    import {setupDevelopmentMode} from "@/utils/developmentMode";
    import {createAuthService} from "../services/authService.svelte";
    import {createTabService} from "../services/tabService.svelte";
    import {settingsService} from "../services/settingsService.svelte";
    import {createInstanceStateService} from "../services/instanceStateService.svelte";
    import {NUI_EVENTS} from "@/constants/nuiEvents";
    import {fetchNui} from "@/utils/fetchNui";
    import {globalNotifications} from "../services/notificationService.svelte";
    import TopBar from "../components/TopBar.svelte";
    import InstanceTabs from "../components/InstanceTabs.svelte";
    import ContentArea from "../components/ContentArea.svelte";
    import RadioPTT from "../components/RadioPTT.svelte";
    import type {AuthUpdateData} from "@/interfaces/IUser";

    const authService = createAuthService();
    const tabService = createTabService();
    const instanceStateService = createInstanceStateService(tabService);

    let opacityStyle = $state("opacity: 1");
    let pointerOutsideTablet = $state(false);

    function handleTabletPointerMove(event: PointerEvent): void {
        if (event.pointerType === 'touch') return;
        const target = event.target;
        // Native-select replacements are portalled to body above the screen.
        // They still belong to the tablet and must not trigger outside fading.
        pointerOutsideTablet = !(target instanceof Element && target.closest('.mdt-window, .sk-menu'));
    }

    function handleOpacityStyleChange(style: string): void {
        opacityStyle = style;
    }

    onMount(() => {
        authService.checkAuth();
        settingsService.loadColorConfig();
        setupInstanceCoordination();
        loadMissedHearings();
    });

    // Global court reminder toast — shows on any tab, not just the calendar
    useNuiEvent<{ title?: string; scheduled_at?: string | number; location?: string }>(
        "courtReminder",
        (data) => {
            const raw = data?.scheduled_at;

            const num = Number(raw);

            const date = raw
                ? new Date(num < 1e12 ? num * 1000 : num)
                : null;

            const when =
                date && !isNaN(date.getTime())
                    ? ` (${date.toLocaleString("en-US", {
                        hour: "2-digit",
                        minute: "2-digit",
                    })})`
                    : "";

            const where = data?.location
                ? ` — ${data.location}`
                : "";

            globalNotifications.info(
                `Appointment: ${data?.title ?? "Hearing"}${when}${where}`
            );
        }
    );

    // On first MDT open, surface hearings whose reminder fired while offline
    async function loadMissedHearings(): Promise<void> {
        try {
            const missed = await fetchNui<Array<{ title: string; scheduled_at?: string }>>(
                NUI_EVENTS.COURT.GET_MISSED,
                {},
                [],
            );
            if (Array.isArray(missed) && missed.length > 0) {
                const titles = missed.slice(0, 3).map((m) => m.title).join(", ");
                const extra = missed.length > 3 ? ` +${missed.length - 3}` : "";
                globalNotifications.info(`Missed Appointment: ${titles}${extra}`);
            }
        } catch {
            /* ignore */
        }
    }

    function setupInstanceCoordination(): void {
        $effect(() => {
            const activeInstance = tabService.getActiveInstance();
            if (activeInstance) {
                instanceStateService.switchToInstance(
                    activeInstance.id,
                    activeInstance.currentTab,
                );
            }
        });
    }

    useNuiEvent<AuthUpdateData>(
        NUI_EVENTS.AUTH.UPDATE_AUTH,
        (data: AuthUpdateData) => {
            authService.updateAuthState(data);
        },
    );

    setupDevelopmentMode();

    if (typeof document !== 'undefined') {
        let lastFocusedInput: HTMLElement | null = null;
        let refocusPending = false;

        document.addEventListener('focusin', (e) => {
            const el = e.target as HTMLElement;
            if (el.tagName === 'INPUT' || el.tagName === 'SELECT' || el.tagName === 'TEXTAREA' || el.isContentEditable) {
                lastFocusedInput = el;
                refocusPending = false;
            }
        });

        document.addEventListener('focusout', (e) => {
            const fe = e as FocusEvent;
            const el = e.target as HTMLElement;
            // Skip SELECT elements - their dropdown interaction triggers focusout with null relatedTarget
            if (el.tagName === 'SELECT') return;
            if (fe.relatedTarget === null && lastFocusedInput === el && !refocusPending) {
                refocusPending = true;
                requestAnimationFrame(() => {
                    if (lastFocusedInput && (!document.activeElement || document.activeElement === document.body)) {
                        lastFocusedInput.focus();
                    }
                    refocusPending = false;
                });
            }
        });

    }
</script>

<svelte:window onpointermove={handleTabletPointerMove} />

<main class="mdt-container" data-job-type={authService.jobType}>
    <RadioPTT />
    <div class="mdt-window" style={pointerOutsideTablet ? 'opacity: 0.25' : opacityStyle}>
        <div class="tablet-camera" aria-hidden="true"><span></span></div>
        <div class="tablet-speaker" aria-hidden="true"></div>
        <div class="tablet-volume" aria-hidden="true"></div>
        <button
                class="tablet-power"
                aria-label="Close tablet"
                title="Close tablet"
                onclick={() => fetchNui(NUI_EVENTS.NAVIGATION.CLOSE_UI)}
        ></button>
        <span class="tablet-screw screw-tl" aria-hidden="true"></span>
        <span class="tablet-screw screw-tr" aria-hidden="true"></span>
        <span class="tablet-screw screw-bl" aria-hidden="true"></span>
        <span class="tablet-screw screw-br" aria-hidden="true"></span>
        <div class="tablet-label" aria-hidden="true">FIELD TERMINAL <span>MDT / SECURE ACCESS</span></div>
        <div class="tablet-status" aria-hidden="true"></div>
        <div class="mdt-interface">
            <TopBar
                    {authService}
                    {tabService}
                    onOpacityStyleChange={handleOpacityStyleChange}
            />

            <div class="mdt-content">
                <div class="mdt-main-content">
                    {#if !authService.isCivilian}
                        <InstanceTabs {tabService}/>
                    {/if}
                    <ContentArea
                            {authService}
                            {tabService}
                            {instanceStateService}
                    />
                </div>
            </div>
        </div>
    </div>
</main>

<style>
    .mdt-container {
        position: fixed;
        top: 0;
        left: 0;
        width: 100vw;
        height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 1000;
    }

    .mdt-window {
        width: 95vw;
        height: 94vh;
        box-sizing: border-box;
        padding: 26px 30px 30px;
        background: linear-gradient(145deg, #2a2b30 0%, #131316 18%, #0a0a0c 65%, #222328 100%);
        border-radius: 34px;
        overflow: visible;
        display: flex;
        flex-direction: column;
        box-shadow: 0 30px 65px rgba(0, 0, 0, 0.65),
            0 5px 0 #08090c,
            inset 0 1px 1px rgba(255, 255, 255, 0.24),
            inset 0 0 0 4px #111419,
            inset 0 0 0 5px rgba(255, 255, 255, 0.06);
        border: 1px solid #444a54;
        position: relative;
        transition: opacity 0.2s ease-in-out;
        will-change: opacity;
    }

    .tablet-camera { position: absolute; top: 8px; left: calc(50% - 5px); width: 10px; height: 10px; border-radius: 50%; background: #080a0e; border: 1px solid #3d4149; box-shadow: inset 0 1px 3px #000; pointer-events: none; }
    .tablet-camera span { display: block; width: 4px; height: 4px; margin: 2px; border-radius: 50%; background: radial-gradient(circle at 30% 30%, #6b98af, #172e49 45%, #060c15 80%); }
    .tablet-speaker { position: absolute; top: 11px; left: calc(50% + 22px); width: 42px; height: 4px; border-radius: 4px; background: repeating-linear-gradient(90deg, #050609 0 2px, #292d34 2px 3px); box-shadow: 0 1px 0 #3a3d43; pointer-events: none; }
    .tablet-volume { position: absolute; top: 72px; left: -4px; width: 4px; height: 72px; background: linear-gradient(90deg, #080a0e, #555b66); border-radius: 3px 0 0 3px; box-shadow: 0 2px 4px #000; pointer-events: none; }
    .tablet-volume::after { content: ''; position: absolute; top: 35px; width: 100%; height: 2px; background: #08090d; }
    .tablet-power { position: absolute; top: 76px; right: -5px; width: 6px; height: 44px; padding: 0; background: linear-gradient(90deg, #535b68, #151820); border: 1px solid #080a0e; border-left: none; border-radius: 0 4px 4px 0; cursor: pointer; box-shadow: 1px 2px 4px #000; }
    .tablet-power::before { content: ''; position: absolute; inset: -7px -6px; }
    .tablet-power:hover { background: #748195; }
    .tablet-screw { position: absolute; width: 6px; height: 6px; border: 1px solid #424853; border-radius: 50%; background: linear-gradient(45deg, #242830 40%, #080a0e 40% 60%, #242830 60%); box-shadow: inset 0 1px 2px #000; pointer-events: none; }
    .screw-tl { top: 16px; left: 15px; }
    .screw-tr { top: 16px; right: 15px; }
    .screw-bl { bottom: 16px; left: 15px; }
    .screw-br { bottom: 16px; right: 15px; }
    .tablet-label { position: absolute; bottom: 9px; left: 40px; color: #8d949f; font-size: 8px; font-weight: 700; letter-spacing: 2.4px; line-height: 1; pointer-events: none; }
    .tablet-label span { margin-left: 14px; color: #525b68; font-size: 7px; letter-spacing: 1.4px; }
    .tablet-status { position: absolute; right: 44px; bottom: 12px; width: 4px; height: 4px; border-radius: 50%; background: var(--accent); box-shadow: 0 0 5px rgba(var(--accent-rgb), 0.7); pointer-events: none; }

    .mdt-interface {
        width: 100%;
        height: 100%;
        display: flex;
        flex-direction: column;
        min-height: 0;
        background:
            radial-gradient(ellipse at 0 0, rgba(var(--accent-rgb), 0.1), transparent 45%),
            var(--dark-bg);
        border-radius: 14px;
        overflow: hidden;
        border: 1px solid #020306;
        border-top: 2px solid var(--accent);
        box-shadow: 0 0 0 2px #05070a, 0 0 0 3px #353a44;
        isolation: isolate;
        position: relative;
    }

    /* my-hud menu panel: accent brackets in the corners and faint scanlines over the screen */
    .mdt-interface::before,
    .mdt-interface::after {
        content: "";
        position: absolute;
        inset: 0;
        z-index: 100;
        pointer-events: none;
    }
    .mdt-interface::before {
        --b: linear-gradient(var(--accent), var(--accent));
        inset: 6px;
        background:
            var(--b) left top / 26px 2px no-repeat, var(--b) left top / 2px 26px no-repeat,
            var(--b) right top / 26px 2px no-repeat, var(--b) right top / 2px 26px no-repeat,
            var(--b) left bottom / 26px 2px no-repeat, var(--b) left bottom / 2px 26px no-repeat,
            var(--b) right bottom / 26px 2px no-repeat, var(--b) right bottom / 2px 26px no-repeat;
        opacity: 0.8;
    }
    .mdt-interface::after { background: repeating-linear-gradient(0deg, rgba(255, 255, 255, 0.018) 0 1px, transparent 1px 3px); }

    .mdt-content {
        display: flex;
        flex: 1;
        min-height: 0;
    }

    .mdt-main-content {
        display: flex;
        flex-direction: column;
        flex: 1;
        min-width: 0;
        width: 100%;
    }

    @media (max-width: 1100px), (max-height: 720px) {
        .mdt-window { width: 97vw; height: 96vh; padding: 22px 18px 24px; border-radius: 26px; }
        .mdt-interface { border-radius: 10px; }
        .tablet-label { bottom: 7px; }
        .tablet-status { bottom: 10px; }
        .tablet-screw { display: none; }
    }
</style>
