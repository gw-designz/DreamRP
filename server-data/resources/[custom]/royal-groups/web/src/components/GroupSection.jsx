import React from 'react';
import useStore from '../state/store';
import { HugeiconsIcon } from '@hugeicons/react';
import { Add01Icon } from '@hugeicons/core-free-icons';
import MemberRow from './MemberRow';

const GroupSection = () => {
    const { group, isLeader, invitePrompt, leaveGroup, disbandGroup, busy } = useStore();
    const leader = isLeader();

    return (
        <div className="gg-card flex flex-col gap-[12px] p-[16px]">
            <div className="flex items-center justify-between gap-[12px]">
                <span className="gg-heading text-[12px] tracking-[0.14em] text-white/45">Your Group</span>

                <div className="flex items-center gap-[8px]">
                    {leader && (
                        <button
                            disabled={!!busy}
                            onClick={() => invitePrompt()}
                            className="gg-pill gg-heading flex items-center gap-[7px] px-[14px] py-[6px] text-[11px] text-white/85 disabled:opacity-30"
                            title="Invite a player by their server id"
                        >
                            <HugeiconsIcon icon={Add01Icon} className="h-[14px] w-[14px]" />
                            Invite
                        </button>
                    )}
                    <button
                        disabled={!!busy}
                        onClick={() => (leader ? disbandGroup() : leaveGroup())}
                        className="gg-pill-danger gg-heading px-[16px] py-[6px] text-[11px] text-white disabled:opacity-40"
                    >
                        {leader ? 'Disband' : 'Leave'}
                    </button>
                </div>
            </div>

            <div className="gg-scroll flex max-h-[300px] flex-col gap-[8px] overflow-y-auto">
                {group.members.map((m) => <MemberRow key={m.id} member={m} />)}
            </div>
        </div>
    );
};

export default GroupSection;