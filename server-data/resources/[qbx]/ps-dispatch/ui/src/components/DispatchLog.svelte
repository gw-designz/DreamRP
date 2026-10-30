<script>
  // Left-hand board panel: running dispatch log (duty changes, attaches,
  // typed messages) and the on-duty units grouped by radio channel.
  import { afterUpdate, createEventDispatcher, tick } from 'svelte';
  import { BOARD_LOG, BOARD_ROSTER } from '@store/stores';
  import { SendNUI } from '@utils/SendNUI';

  const emit = createEventDispatcher();

  let tab = 'log';
  let draft = '';
  let listEl;
  let stickToBottom = true;
  let lastCount = 0;

  function clock(t) {
    const d = new Date(t);
    return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
  }

  // Follow new entries only while the reader is already at the bottom, so
  // scrolling back through history isn't yanked away by the next line.
  function onScroll() {
    stickToBottom = listEl.scrollHeight - listEl.scrollTop - listEl.clientHeight < 24;
  }
  afterUpdate(() => {
    if (tab !== 'log' || !listEl) return;
    if ($BOARD_LOG.length !== lastCount && stickToBottom) listEl.scrollTop = listEl.scrollHeight;
    lastCount = $BOARD_LOG.length;
  });

  async function showLog() {
    tab = 'log';
    stickToBottom = true;
    lastCount = -1;
    await tick();
  }

  function send() {
    const text = draft.trim();
    if (!text) return;
    SendNUI('boardMessage', { text });
    draft = '';
    stickToBottom = true;
  }

  // Radio tab: units grouped by channel, lowest channel first.
  $: channels = (() => {
    const map = new Map();
    for (const u of $BOARD_ROSTER) {
      const key = u.radio ?? 'none';
      if (!map.has(key)) map.set(key, []);
      map.get(key).push(u);
    }
    return [...map.entries()].sort(([a], [b]) =>
      a === 'none' ? 1 : b === 'none' ? -1 : Number(a) - Number(b));
  })();
</script>

<div class="pd-log">
  <div class="pd-log-head">
    <i class="fas fa-message pd-log-head-icon"></i>
    <span class="pd-log-title">Dispatch Log</span>
    <button class="pd-hbtn" title="Settings" on:click={() => emit('settings')}><i class="fas fa-gear"></i></button>
  </div>

  <div class="pd-seg pd-seg--flat">
    <button class="pd-seg-btn" class:pd-seg-btn--active={tab === 'log'} on:click={showLog}>Dispatch Log</button>
    <button class="pd-seg-btn" class:pd-seg-btn--active={tab === 'radio'} on:click={() => tab = 'radio'}>Radio Channels</button>
  </div>

  {#if tab === 'log'}
    <div class="pd-log-list pd-scroll" bind:this={listEl} on:scroll={onScroll}>
      {#each $BOARD_LOG as entry (entry.id)}
        <div class="pd-log-row" class:pd-log-row--msg={entry.kind === 'msg'}>
          <span class="pd-log-time"><i class="fas fa-stopwatch"></i>{clock(entry.time)}</span>
          <span class="pd-log-text">
            {#if entry.callsign}<span class="pd-chip-cs">{entry.callsign}</span>{/if}
            {#if entry.kind === 'msg'}<b>{entry.author}:</b>{/if}
            {entry.text}
          </span>
        </div>
      {:else}
        <p class="pd-log-empty">Nothing logged yet</p>
      {/each}
    </div>

    <form class="pd-log-input" on:submit|preventDefault={send}>
      <input class="pd-input" placeholder="Type a message..." maxlength="200" bind:value={draft} />
      <button class="pd-send" type="submit" title="Send"><i class="fas fa-share"></i></button>
    </form>
  {:else}
    <div class="pd-log-list pd-scroll">
      {#each channels as [channel, units] (channel)}
        <div class="pd-radio">
          <div class="pd-radio-head">
            <i class="fas fa-walkie-talkie"></i>
            {channel === 'none' ? 'Not on radio' : `Channel ${channel}`}
            <span class="pd-radio-count">{units.length}</span>
          </div>
          <div class="pd-radio-units">
            {#each units as u (u.src)}
              <span class="pd-chip">
                <span class="pd-chip-cs {u.dept === 'ems' ? 'pd-chip-cs--ems' : ''}">{u.callsign || '—'}</span>{u.name}
              </span>
            {/each}
          </div>
        </div>
      {:else}
        <p class="pd-log-empty">No units on duty</p>
      {/each}
    </div>
  {/if}
</div>
