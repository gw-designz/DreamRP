<script>
  // One call in a dispatch panel: compact row, expandable in place to the
  // full section anatomy (map thumb, location/vehicle strips, danger banner,
  // person line, note, units, attach button). Extracted from Menu.svelte so
  // the pending list and the Active Calls board share one implementation.
  import { createEventDispatcher } from 'svelte';
  import Plate from './Plate.svelte';
  import { slide } from 'svelte/transition';
  import { DUR, EASE_OUT } from '@utils/motion';
  import { PLAYER, Locale, MAP_IMAGE, UNATTENDED_AFTER, PINNED_CODES, THUMBS_ENABLED, REDUCED_MOTION } from '@store/stores';
  import { clockAndAge, now } from '@utils/timeAgo';
  import { SendNUI } from '@utils/SendNUI';
  import MapThumb from './MapThumb.svelte';

  export let dispatch;              // the call
  export let expanded = false;      // parent-controlled (one open at a time)
  export let isIncident = false;    // declared a major incident
  export let mayDeclare = false;    // this player's grade allows declaring

  // Declaring changes everyone's board, so it takes the same two-step confirm
  // the clear button already uses in this file.
  // Same copy path as the plate log: navigator.clipboard needs a secure
  // context, which the NUI is not.
  let copiedPlate = false;
  function copyPlate() {
    try {
      const ta = document.createElement('textarea');
      ta.value = dispatch.plate;
      ta.style.cssText = 'position:fixed;opacity:0;pointer-events:none;';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      ta.remove();
      copiedPlate = true;
      setTimeout(() => (copiedPlate = false), 1400);
    } catch { /* nothing sensible to say if the host blocks it */ }
  }

  // Silhouette per class — a shape reads faster than a word when you are
  // driving. Font Awesome has no shotgun or SMG, so the closest gun glyph
  // stands in and the label carries the detail.
  const WEAPON_ICON = {
    pistol: 'fa-gun', smg: 'fa-gun', rifle: 'fa-crosshairs',
    shotgun: 'fa-gun', sniper: 'fa-crosshairs', heavy: 'fa-burst',
    taser: 'fa-bolt',
  };
  const WEAPON_LABEL = {
    pistol: 'Handgun', smg: 'Submachine gun', rifle: 'Rifle',
    shotgun: 'Shotgun', sniper: 'Long rifle', heavy: 'Heavy weapon',
    taser: 'Taser',
  };

  let confirmDeclare = false;
  $: if (!expanded) confirmDeclare = false;

  function toggleIncident() {
    if (isIncident) {
      SendNUI('standDownIncident', { id: dispatch.id });
      return;
    }
    if (!confirmDeclare) { confirmDeclare = true; return; }
    confirmDeclare = false;
    SendNUI('declareIncident', {
      id: dispatch.id,
      title: dispatch.message,
      code: dispatch.code,
      street: dispatch.street,
    });
  }

  const emit = createEventDispatcher();
  let showAllUnits = false;
  // Units arrive in attach order from the server, so the first slice is always
  // the units that got there first — no sorting needed.
  const UNIT_LIMIT = 5;

  // Priority 0 sits above the existing red. Everything that used to ask
  // "== 1" now asks "<= 1", so critical inherits every urgent treatment and
  // adds its own on top — otherwise the most important call on the board
  // would have rendered as routine.
  $: isCritical = (dispatch.priority ?? 3) <= 0;
  $: isUrgent = (dispatch.priority ?? 3) <= 1;
  let confirmClear = false;
  let noteDraft = '';
  let noteOpen = false;

  // Reset the transient editor state only when this row actually switches to
  // a DIFFERENT call. Reacting to `dispatch` itself would fire on every store
  // update (unit counts and notes hand down fresh array copies), closing the
  // note editor mid-typing.
  let lastId = null;
  $: if (dispatch.id !== lastId) {
    lastId = dispatch.id;
    confirmClear = false;
    noteOpen = false;
  }

  function openNote() {
    noteDraft = dispatch.dispatchNote || '';
    noteOpen = true;
  }

  function saveNote() {
    SendNUI('setCallNote', { id: dispatch.id, note: noteDraft });
    noteOpen = false;
  }

  // Armed state lapses on its own so a stray first click can't linger.
  let disarm;
  function clearCall() {
    clearTimeout(disarm);
    if (!confirmClear) {
      confirmClear = true;
      disarm = setTimeout(() => (confirmClear = false), 3000);
      return;
    }
    SendNUI('clearCall', { id: dispatch.id });
    confirmClear = false;
  }

  function attach() {
    SendNUI('attachUnit', dispatch);
    SendNUI('refreshAlerts');
  }

  function detach() {
    SendNUI('detachUnit', dispatch);
    SendNUI('refreshAlerts');
  }

  // "Hawick Ave, Burton" -> "Hawick Ave · Burton"
  function placeText(street) {
    return street ? street.split(', ').join(' · ') : 'Unknown location';
  }

  // Live count support: a unitCount push is always newer than the units
  // array from the last list refresh, so it wins when present — in both
  // directions (remote detaches must drop the badge too).
  $: unitCount = dispatch.unitsLive !== undefined ? dispatch.unitsLive : (dispatch.units?.length || 0);

  function CheckIfAttached(units, player) {
    for (let i = 0; i < (units?.length || 0); i++) {
      if (units[i].citizenid === player) return true;
    }
    return false;
  }

  // Triage: true when nobody is attached and the call has been waiting
  // longer than Config.UnattendedAfter minutes.
  function unattendedFor(d) {
    if (!$UNATTENDED_AFTER) return 0;
    if (unitCount > 0) return 0;
    const min = Math.floor((Date.now() - d.time) / 60000);
    return min >= $UNATTENDED_AFTER ? min : 0;
  }

  // Rendered as one "1803 | 5965770628" line, same as the alert card.
  function personLine(d) {
    return [d.callsign, d.name, d.gender, d.number].filter(Boolean);
  }

  function vehicleBadges(d) {
    const out = [];
    if (d.color) out.push(d.color);
    if (d.class) out.push(d.class);
    if (d.doors) out.push(`${d.doors} doors`);
    return out;
  }
</script>

<div
  class="pd-card {isUrgent ? 'pd-card--priority' : ''} {isCritical ? ($REDUCED_MOTION ? 'pd-card--critical pd-no-pulse' : 'pd-card--critical') : ''} {isIncident ? 'pd-card--incident' : ''}"
  data-call-id={dispatch.id}
>
  <div class="pd-card-top">
    <div class="pd-card-head">
      <div class="pd-tile"><i class={dispatch.icon}></i></div>
      <span class="pd-card-title">{dispatch.message}</span>
      {#if isCritical}<span class="pd-badge pd-badge--critical flex-shrink-0">Critical</span>{/if}
      {#if $PINNED_CODES.includes(dispatch.codeName)}
        <span class="pd-badge pd-badge--red flex-shrink-0" title="Pinned critical call"><i class="fas fa-thumbtack"></i></span>
      {/if}
      {#if (dispatch.count || 1) > 1}
        <span class="pd-badge pd-badge--red flex-shrink-0">×{dispatch.count}</span>
      {/if}
      {#if dispatch.hotspot}
        <span class="pd-badge pd-badge--purple flex-shrink-0" title="Repeated incidents on this street"><i class="fas fa-fire mr-[3px]"></i>×{dispatch.hotspot}</span>
      {/if}
      {#if unattendedFor(dispatch)}
        <span class="pd-badge pd-badge--amber flex-shrink-0" title="No units attached"><i class="fas fa-clock mr-[3px]"></i>{unattendedFor(dispatch)}m</span>
      {/if}
      {#if dispatch.code}<span class="pd-card-code">{dispatch.code}</span>{/if}
      {#if !dispatch.footer}
        <button class="pd-hbtn" title="Set waypoint" on:click={() => SendNUI('setCallWaypoint', dispatch)}>
          <i class="fas fa-location-dot"></i>
        </button>
      {/if}
      <!-- Clearing removes the call for everyone, so the first click only arms it. -->
      <button class="pd-hbtn {confirmClear ? 'pd-hbtn--danger' : ''}" title={confirmClear ? 'Click again to clear' : 'Clear call'} on:click={clearCall}>
        <i class="fas fa-{confirmClear ? 'check' : 'xmark'}"></i>
      </button>
    </div>

    {#if !dispatch.footer}
      <div class="pd-card-loc">
        <i class="fas fa-location-dot"></i>
        <span class="pd-card-loc-text">{placeText(dispatch.street)}</span>
        <span class="pd-card-when">{clockAndAge(dispatch.time, $now)}</span>
      </div>
    {/if}
  </div>

  <div class="pd-card-body">
    {#if dispatch.information}
      <div class="pd-line"><i class="fas fa-bell"></i><span>{dispatch.information}</span></div>
    {/if}

    {#if personLine(dispatch).length}
      <div class="pd-line pd-line--muted"><i class="fas {dispatch.information ? 'fa-user' : 'fa-bell'}"></i><span>{personLine(dispatch).join(' | ')}</span></div>
    {/if}

    {#if dispatch.vehicle || dispatch.plate}
      <div class="pd-line pd-line--muted">
        <i class="fas fa-car"></i>
        <div class="pd-line-body">
          <span>{dispatch.vehicle || 'Unknown vehicle'}</span>
          {#if dispatch.plate}
            <Plate plate={dispatch.plate} index={dispatch.plateIndex} />
            <span
              class="pd-copy pd-copy--shown"
              class:pd-copy--done={copiedPlate}
              role="button"
              tabindex="-1"
              title={copiedPlate ? 'Copied' : 'Copy plate'}
              on:click|stopPropagation={copyPlate}
              on:keydown|stopPropagation
            >
              <i class="fas {copiedPlate ? 'fa-check' : 'fa-copy'}"></i>
            </span>
          {/if}
          {#each vehicleBadges(dispatch) as b}<span class="pd-badge">{b}</span>{/each}
        </div>
      </div>
    {/if}

    {#if dispatch.weapon || dispatch.automaticGunFire}
      <div class="pd-line pd-line--muted pd-line--t{dispatch.weaponTier || 1}">
        <i class="fas {WEAPON_ICON[dispatch.weaponClass] || 'fa-gun'}"></i>
        <div class="pd-line-body">
          <span>{WEAPON_LABEL[dispatch.weaponClass] || dispatch.weapon || 'Shots fired'}</span>
          {#if dispatch.weapon && WEAPON_LABEL[dispatch.weaponClass]}<span class="pd-weap-model">{dispatch.weapon}</span>{/if}
          {#if dispatch.automaticGunFire}<span class="pd-badge pd-badge--red">Automatic</span>{/if}
        </div>
      </div>
    {/if}

    {#if dispatch.dispatchNote && !noteOpen}
      <div class="pd-note pd-note--dispatch">
        <span class="pd-note-tag">Dispatch</span>{dispatch.dispatchNote}
      </div>
    {/if}

    <!-- Units, then the call's actions: details, unit count, attach. -->
    <div class="pd-card-actions">
      <div class="pd-card-units">
        {#each (dispatch.units || []).slice(0, showAllUnits ? dispatch.units.length : UNIT_LIMIT) as unit}
          <span class="pd-chip">
            <span class="pd-chip-cs {unit.job?.type == 'ems' ? 'pd-chip-cs--ems' : ''}">{unit.metadata?.callsign || '—'}</span>
            {unit.charinfo?.firstname} {unit.charinfo?.lastname}
            {#if unit.citizenid === $PLAYER.citizenid}
              <!-- Only your own chip can be removed: detaching is per-unit. -->
              <button class="pd-chip-x" title={$Locale.dispatch_detach} on:click={detach}><i class="fas fa-xmark"></i></button>
            {/if}
          </span>
        {/each}
        {#if (dispatch.units?.length || 0) > UNIT_LIMIT}
          <button class="pd-more-units !w-auto !mt-0" on:click={() => showAllUnits = !showAllUnits}>
            {showAllUnits ? 'Show fewer' : `+${dispatch.units.length - UNIT_LIMIT} ${$Locale.additionals}`}
          </button>
        {/if}
      </div>

      <button class="pd-hbtn {expanded ? 'pd-hbtn--on' : ''}" title={expanded ? 'Hide details' : 'Details'} on:click={() => emit('toggle')}>
        <i class="fas fa-{expanded ? 'minus' : 'plus'}"></i>
      </button>
      <span class="pd-pill {unitCount ? '' : 'pd-pill--muted'}" title="Units attached">
        <i class="fas fa-user"></i>{unitCount}
      </span>
      {#if CheckIfAttached(dispatch.units, $PLAYER.citizenid)}
        <button class="pd-obtn pd-obtn--on" on:click={detach}>
          <i class="fas fa-link-slash"></i> {$Locale.dispatch_detach}
        </button>
      {:else}
        <button class="pd-obtn" on:click={attach}>
          <i class="fas fa-link"></i> {$Locale.dispatch_attach}
        </button>
      {/if}
    </div>
  </div>

  {#if expanded}
    <div class="pd-card-detail" transition:slide={{ duration: DUR.base, easing: EASE_OUT }}>
      <!-- Answers get no map: an alert carrying a footer is an ANSWER (plate
           check, record lookup), targeted at the officer standing there. -->
      {#if $MAP_IMAGE && $THUMBS_ENABLED && !dispatch.footer}
        <!-- Click opens the enlarged, zoomable map (handled by the parent so
             there is only ever one overlay). -->
        <div class="pd-thumb-click" title="Enlarge map" on:click={() => emit('expandMap')}>
          <MapThumb coords={dispatch.displayCoords || dispatch.coords} radius={dispatch.mapRadius || 0} priority={dispatch.priority} src={$MAP_IMAGE} height={110} />
          <span class="pd-thumb-zoom"><i class="fas fa-magnifying-glass-plus"></i></span>
        </div>
      {/if}

      {#if dispatch.heading}
        <div class="pd-line pd-line--muted"><i class="fas fa-compass"></i><span>Heading {dispatch.heading}</span></div>
      {/if}

      {#if noteOpen}
        <div class="pd-note-editor">
          <input
            class="pd-input"
            placeholder="Note for every unit on this call…"
            maxlength="240"
            bind:value={noteDraft}
            on:keydown={(e) => { if (e.key === 'Enter') saveNote(); if (e.key === 'Escape') noteOpen = false; }}
          />
          <button class="pd-btn pd-btn--green" on:click={saveNote}><i class="fas fa-check"></i></button>
          <button class="pd-btn" on:click={() => noteOpen = false}><i class="fas fa-xmark"></i></button>
        </div>
      {/if}

      <div class="flex gap-[5px]">
        <button class="pd-btn flex-1" on:click={noteOpen ? () => noteOpen = false : openNote}>
          <i class="fas fa-pen"></i> {dispatch.dispatchNote ? 'Edit note' : 'Add note'}
        </button>
        {#if mayDeclare}
          <button class="pd-btn {isIncident || confirmDeclare ? 'pd-btn--red' : ''} flex-1" on:click|stopPropagation={toggleIncident}>
            {#if isIncident}
              <i class="fas fa-xmark"></i> Stand down incident
            {:else if confirmDeclare}
              <i class="fas fa-triangle-exclamation"></i> Confirm — pins for all
            {:else}
              <i class="fas fa-tower-broadcast"></i> Declare major incident
            {/if}
          </button>
        {/if}
      </div>
    </div>
  {/if}
</div>
