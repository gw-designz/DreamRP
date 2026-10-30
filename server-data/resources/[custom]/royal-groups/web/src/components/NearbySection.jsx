import React from 'react';
import useStore from '../state/store';
import NearbyRow from './NearbyRow';

const NearbySection = () => {
    const nearby = useStore((s) => s.nearby);

    return (
        <div className="gg-card flex flex-col gap-[12px] p-[16px]">
            <span className="gg-heading text-[12px] tracking-[0.14em] text-white/45">Nearby Players</span>

            {nearby.length === 0 ? (
                <div className="py-[18px] text-center text-[13px] text-white/35">No players nearby.</div>
            ) : (
                <div className="gg-scroll flex max-h-[220px] flex-col gap-[8px] overflow-y-auto">
                    {nearby.map((p) => <NearbyRow key={p.id} player={p} />)}
                </div>
            )}
        </div>
    );
};

export default NearbySection;