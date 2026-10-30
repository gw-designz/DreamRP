// Small Leaflet map (same tiles / projection as the Maps app) that follows the player and
// shows optional pickup / dropoff markers. Player position streams from client/app/maps.
import { useEffect, useRef } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { MAP, CUSTOM_CRS, toLatLng, MAP_BOUNDS, tileUrl } from '../../app/maps/crs';
import { fetchNui } from '../../utils/fetchNui';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { isEnvBrowser } from '../../utils/misc';

const icon = (cls) => L.divIcon({ className: `npm-pin npm-pin--${cls}`, html: '<span></span>', iconSize: [22, 22], iconAnchor: [11, 11] });
const ICONS = { player: icon('player'), pickup: icon('pickup'), dropoff: icon('dropoff') };

export default function NpMap({ markers = [], className = '', zoom = 4 }) {
    const el = useRef(null);
    const map = useRef(null);
    const me = useRef(null);
    const layer = useRef(null);
    const centered = useRef(false);

    useEffect(() => {
        const m = L.map(el.current, {
            crs: CUSTOM_CRS,
            minZoom: 2,
            maxZoom: 5,
            zoomControl: false,
            attributionControl: false,
            layers: [L.tileLayer(tileUrl, { minZoom: MAP.minZoom, maxZoom: MAP.maxZoom, noWrap: true })],
            center: [0, 0],
            zoom,
            maxBounds: MAP_BOUNDS,
            maxBoundsViscosity: 1,
        });
        map.current = m;
        layer.current = L.layerGroup().addTo(m);
        setTimeout(() => m.invalidateSize(), 120);
        fetchNui('phone:maps:enter', {}, {});
        if (isEnvBrowser()) {
            me.current = L.marker(toLatLng(-500, 600), { icon: ICONS.player }).addTo(m);
            m.setView(toLatLng(-500, 600), zoom);
        }
        return () => {
            fetchNui('phone:maps:exit', {}, {});
            m.remove();
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    useNuiEvent('phone:maps:pos', (p) => {
        const m = map.current;
        if (!m || !p) return;
        const ll = toLatLng(p.x, p.y);
        if (!me.current) me.current = L.marker(ll, { icon: ICONS.player, zIndexOffset: 1000 }).addTo(m);
        else me.current.setLatLng(ll);
        if (!centered.current) {
            m.setView(ll, zoom);
            centered.current = true;
        }
    });

    const key = JSON.stringify(markers);
    useEffect(() => {
        const g = layer.current;
        if (!g) return;
        g.clearLayers();
        for (const mk of markers) {
            if (typeof mk.x !== 'number') continue;
            L.marker(toLatLng(mk.x, mk.y), { icon: ICONS[mk.kind] || ICONS.dropoff }).addTo(g);
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [key]);

    return <div ref={el} className={`npm ${className}`} />;
}
