<script>
  // "(12) Police" / "(5) EMS": on-duty units of one department, grouped into
  // command, on a call and available. Clicking a unit waypoints to them.
  import { slide } from 'svelte/transition';
  import { DUR, EASE_OUT } from '@utils/motion';
  import { BOARD_ROSTER, PLAYER } from '@store/stores';
  import { SendNUI } from '@utils/SendNUI';
  import { createEventDispatcher } from 'svelte';

  export let dept = 'leo';
  export let title = 'Police';
  export let open = true;

  const emit = createEventDispatcher();

  const VEHICLE_ICON = {
    car: 'fa-car-side', bike: 'fa-motorcycle', heli: 'fa-helicopter',
    plane: 'fa-plane', boat: 'fa-ship',
  };

  $: units = $BOARD_ROSTER.filter(u => u.dept === dept);
  $: groups = [
    ['Watch Commander', units.filter(u => u.command)],
    ['On a Call', units.filter(u => !u.command && u.callId != null)],
    ['Available', units.filter(u => !u.command && u.callId == null)],
  ].filter(([, list]) => list.length);

  function unitLabel(n) {
    return `${n} ${n === 1 ? 'UNIT' : 'UNITS'}`;
  }
</script>

<div class="pd-roster" class:pd-roster--closed={!open}>
  <button class="pd-roster-head" on:click={() => open = !open}>
    <span class="pd-roster-title">({units.length}) {title}</span>
    <i class="fas fa-chevron-{open ? 'up' : 'down'}"></i>
  </button>

  {#if open}
    <div class="pd-roster-body pd-scroll" transition:slide={{ duration: DUR.base, easing: EASE_OUT }}>
      {#each groups as [label, list] (label)}
        <div class="pd-roster-label">{label.toUpperCase()} ({unitLabel(list.length)})</div>
        {#each list as u (u.src)}
          <button class="pd-roster-row" class:pd-roster-row--me={u.citizenid === $PLAYER?.citizenid} title="{u.fullName}{u.grade ? ' · ' + u.grade : ''} — click to set waypoint" on:click={() => SendNUI('locateUnit', { src: u.src })}>
            <span class="pd-roster-icon pd-roster-icon--{u.command ? 'cmd' : u.callId != null ? 'busy' : 'free'}">
              <i class="fas {u.command ? 'fa-star' : VEHICLE_ICON[u.vehicle] || 'fa-person-walking'}"></i>
            </span>
            <span class="pd-chip-cs {dept === 'ems' ? 'pd-chip-cs--ems' : ''}">{u.callsign || '—'}</span>
            <span class="pd-roster-name">{u.name}</span>
            {#if u.callId != null}
              <span class="pd-pill pd-pill--sm" role="button" tabindex="-1" title="Show call" on:click|stopPropagation={() => emit('focusCall', u.callId)} on:keydown>#{u.callId}</span>
            {/if}
            {#if u.radio}
              <span class="pd-roster-radio" title="Radio channel"><i class="fas fa-walkie-talkie"></i>{u.radio}</span>
            {/if}
          </button>
        {/each}
      {:else}
        <p class="pd-log-empty">No units on duty</p>
      {/each}
    </div>
  {/if}
</div>
