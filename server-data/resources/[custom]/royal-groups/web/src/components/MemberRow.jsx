import React from 'react';
import useStore from '../state/store';
import { HugeiconsIcon } from '@hugeicons/react';
import { UserRemove01Icon, CrownIcon } from '@hugeicons/core-free-icons';

const MemberRow = ({ member }) => {
    const { me, group, isLeader, kickMember, promoteMember, busy } = useStore();
    const isSelf = member.id === me?.id;
    const isGroupLeader = member.id === group.leaderId;
    const canManage = isLeader() && !isSelf;

    return (
        <div className={`gg-row flex items-center justify-between gap-[12px] px-[16px] py-[11px] ${isSelf ? 'self' : ''}`}>
            <span className="min-w-0 truncate text-[14px] font-bold text-white">
                {member.nickname || member.name}
            </span>

            {isGroupLeader ? (
                <span className="gg-heading shrink-0 text-[11px] tracking-[0.12em] text-white/45">
                    Leader{isSelf ? ' (You)' : ''}
                </span>
            ) : canManage ? (
                <div className="flex shrink-0 items-center gap-[14px]">
                    <button
                        disabled={!!busy}
                        title="Kick from group"
                        onClick={() => kickMember(member)}
                        className="gg-icon-btn hover:!text-red-400"
                    >
                        <HugeiconsIcon icon={UserRemove01Icon} className="h-[18px] w-[18px]" />
                    </button>
                    <button
                        disabled={!!busy}
                        title="Make leader"
                        onClick={() => promoteMember(member)}
                        className="gg-icon-btn"
                    >
                        <HugeiconsIcon icon={CrownIcon} className="h-[18px] w-[18px]" />
                    </button>
                </div>
            ) : null}
        </div>
    );
};

export default MemberRow;
