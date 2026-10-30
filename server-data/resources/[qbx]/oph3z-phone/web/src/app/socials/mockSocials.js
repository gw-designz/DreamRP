// Browser-preview data only. fetchNui() returns these mocks exclusively outside FiveM
// (utils/misc.isEnvBrowser); in game every call goes to the server.
const now = Math.floor(Date.now() / 1000);
const acc = (id, name) => ({ id, handle: name.toLowerCase(), name, avatar: null });

const second = acc(2, 'secondclient');
const raptox = acc(1, 'Raptox');

export const MOCK_ME = raptox;

export const MOCK_FEED = [
    {
        id: 11, text: 'qwdqwd', media: [], createdAt: now - 86400 * 3, author: second,
        likeCount: 0, liked: false, replyCount: 2, repostCount: 1, reposted: true,
        viewCount: 1, bookmarked: false, repostBy: raptox,
    },
    {
        id: 11, text: 'qwdqwd', media: [], createdAt: now - 86400 * 3, author: second,
        likeCount: 0, liked: false, replyCount: 2, repostCount: 1, reposted: true,
        viewCount: 1, bookmarked: false,
    },
    {
        id: 10, text: 'qwdqwdqd', media: [], createdAt: now - 86400 * 3, author: second,
        likeCount: 1, liked: true, replyCount: 0, repostCount: 0, reposted: false,
        viewCount: 0, bookmarked: false,
    },
    {
        id: 9, text: 'Hit me up if you need a ride on #guber.', media: [], createdAt: now - 70,
        author: acc(5, 'Lang'), likeCount: 0, liked: false, replyCount: 0, repostCount: 0,
        reposted: false, viewCount: 1, bookmarked: false,
    },
    {
        id: 8, text: 'test', media: [], createdAt: now - 86400 * 40, author: raptox,
        likeCount: 0, liked: false, replyCount: 0, repostCount: 0, reposted: false,
        viewCount: 0, bookmarked: true,
    },
];

export const MOCK_THREAD = {
    ok: true,
    post: { ...MOCK_FEED[1] },
    ancestors: [],
    replies: [
        {
            id: 20, text: 'Test', parentId: 11, createdAt: now - 60, author: raptox,
            media: [], likeCount: 0, liked: false, replyCount: 0, repostCount: 0,
            reposted: false, viewCount: 0, bookmarked: false,
        },
        {
            id: 21, text: 'qwdqdwqd', parentId: 11, createdAt: now - 30, author: raptox,
            media: [], likeCount: 0, liked: false, replyCount: 0, repostCount: 0,
            reposted: false, viewCount: 0, bookmarked: false,
        },
    ],
};

export const MOCK_NOTIFS = [
    { id: 1, type: 'like', actor: second, verb: 'liked your post', postId: 8, ts: now - 300, read: false },
    { id: 2, type: 'follow', actor: acc(5, 'Lang'), verb: 'followed you', ts: now - 4000, read: true },
];

export const MOCK_PROFILE = {
    ...raptox, bio: 'Los Santos local.', followersCount: 3, followingCount: 2, isMe: true,
    isFollowing: false, createdAt: now - 86400 * 90, posts: [MOCK_FEED[4], MOCK_FEED[0]], replies: [],
};
