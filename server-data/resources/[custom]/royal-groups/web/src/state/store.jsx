import { create } from 'zustand';
import SendNuiCallback from '../utils/sendnuicallback';
import isEnvBrowser from '../utils/isEnvBrowser';
import { MOCK_ME, MOCK_GROUP, MOCK_NEARBY } from '../data/mock';

const list = (value, fallback = []) =>
    Array.isArray(value) ? value : value && typeof value === 'object' ? Object.values(value) : fallback;

const withMembers = (group) => (group ? { ...group, members: list(group.members) } : null);

const useStore = create((set, get) => {
    const call = async (endpoint, data = {}, applyMock) => {
        set({ busy: endpoint });
        if (isEnvBrowser()) {
            await new Promise((r) => setTimeout(r, 250));
            set((s) => ({ busy: null, ...(applyMock ? applyMock(s) : null) }));
            return { success: true };
        }
        const res = await SendNuiCallback(endpoint, data);
        set({ busy: null });
        return res ?? { success: false };
    };

    return {
        visible: false,
        me: null,
        group: null,
        nearby: [],
        busy: null,

        setState: (payload) => {
            switch (payload.type) {
                case 'open':
                    set({
                        visible: true,
                        me: payload.me ?? null,
                        group: withMembers(payload.group),
                        nearby: list(payload.nearby),
                    });
                    break;
                case 'update':
                    set((s) => ({
                        me: payload.me ?? s.me,
                        group: payload.group !== undefined ? withMembers(payload.group) : s.group,
                        nearby: payload.nearby !== undefined ? list(payload.nearby, s.nearby) : s.nearby,
                    }));
                    break;
                case 'close':
                    set({ visible: false, busy: null });
                    break;
                default:
                    break;
            }
        },

        hide: () => {
            set({ visible: false, busy: null });
            SendNuiCallback('close');
        },

        isLeader: () => {
            const { me, group } = get();
            return !!group && !!me && group.leaderId === me.id;
        },

        createGroup: () =>
            call('createGroup', {}, (s) => ({
                group: { id: 'RYL-0001', leaderId: s.me.id, members: [{ ...s.me }] },
            })),

        // the client asks for a server id in an ox_lib dialog and invites from there
        invitePrompt: () => call('invitePrompt'),

        invitePlayer: (player) =>
            call('invitePlayer', { id: player.id }, (s) => ({
                nearby: s.nearby.filter((p) => p.id !== player.id),
            })),

        kickMember: (member) =>
            call('kickMember', { id: member.id }, (s) => ({
                group: s.group && { ...s.group, members: s.group.members.filter((m) => m.id !== member.id) },
            })),

        promoteMember: (member) =>
            call('promoteMember', { id: member.id }, (s) => ({
                group: s.group && { ...s.group, leaderId: member.id },
            })),

        leaveGroup: () => call('leaveGroup', {}, () => ({ group: null })),

        disbandGroup: () => call('disbandGroup', {}, () => ({ group: null })),

        setNickname: (nickname) =>
            call('setNickname', { nickname }, (s) => ({
                group: s.group && {
                    ...s.group,
                    members: s.group.members.map((m) => (m.id === s.me.id ? { ...m, nickname } : m)),
                },
            })),

        loadMock: () => set({ visible: true, me: MOCK_ME, group: MOCK_GROUP, nearby: MOCK_NEARBY }),
    };
});

export default useStore;
