<script>
  // Top-centre strip while the menu is open: heading, street, zone.
  import { STREET_HUD } from '@store/stores';
</script>

{#if $STREET_HUD}
  <div class="pd-street">
    <span><i class="fas fa-compass"></i>{$STREET_HUD.heading}</span>
    {#if $STREET_HUD.street}<span><i class="fas fa-location-dot"></i>{$STREET_HUD.street}</span>{/if}
    {#if $STREET_HUD.zone}<span><i class="fas fa-map"></i>{$STREET_HUD.zone}</span>{/if}
  </div>
{/if}
