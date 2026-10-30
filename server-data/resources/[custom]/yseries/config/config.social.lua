Config = Config or {}

Config.YBuy = Config.YBuy or {}
-- Whether you want to send a notification to all players when a new ad is created.
Config.YBuy.GlobalNotifications = true

Config.Y = {}
-- Whether you want to send a notification to all players when a new post is created.
Config.Y.GlobalNotifications = true

Config.Instashots = {}
--- Server-wide Instashots push notifications (sent to every player with a phone; respects per-app notification settings).
Config.Instashots.GlobalNotifications = {
    --- When someone publishes a new post.
    newPost = true,
    --- When someone starts a live stream (only applies if `AllowLive` is true).
    liveStarted = true,
}

-- The default posts that will be shown when you open the app.
-- *foryou - Shows all posts in the server.
-- *following - Shows only the posts of the people you follow.
Config.Instashots.DefaultLoadPreference = 'foryou' -- 'foryou' or 'following'

-- The default stories that will be shown when you open the app.
-- *foryou - Shows all stories in the server.
-- *following - Shows only the stories of the people you follow.
Config.Instashots.DefaultStoryLoadPreference = 'foryou' -- 'foryou' or 'following'

-- Whether you want to allow users to go live.
Config.Instashots.AllowLive = true

Config.DarkChat = {}

-- Whether you want to insert every new member to the general chat(DarkChat).
Config.DarkChat.GeneralInsertNewMembers = false

Config.PromoHub = Config.PromoHub or {}

Config.PromoHub.GlobalNotifications = true

Config.PromoHub.Tags = {
    {
        label = 'Vehicle',
        color = '#ffea2f',
    },
    {
        label = 'Service',
        color = '#ffbd2f',
    },
    {
        label = 'Rent',
        color = '#30ad4b',
    },
    {
        label = 'Sale',
        color = '#52ff2f',
    },
    {
        label = 'Job',
        color = '#ff7b2f',
    },
    {
        label = 'House',
        color = '#dc2fff',
    },
    {
        label = 'Electronics',
        color = '#ff2f2f',
    },
    {
        label = 'Promo',
        color = '#10b180',
    },
    {
        label = 'Deal',
        color = '#2fc4ff',
    },
    {
        label = 'Other',
        color = '#4e1966',
    },
}

Config.Lovr = {}

-- Available gender options for user profiles
Config.Lovr.GenderOptions = {
    'male',
    'female',
    'other'
}

-- Available interested_in options for user preferences
Config.Lovr.InterestedInOptions = {
    'male',
    'female',
    'both'
}

Config.News = {}

Config.News.Jobs = { 'reporter', 'weazel' }

Config.News.Categories = { 'general', 'crime', 'funny', 'politics', 'health' }

Config.Audix = {}

-- Whether you want to restrict Audix ringtone uploads to admin only.
-- If true, only admins can upload songs.
Config.Audix.AdminOnlyUpload = true

Config.YouToo = {}
Config.YouToo.TrendingVideos = {
    {
        title = "Timeless Music Hits - Best Music 2000 to 2025 Playlist - Music Hits 2000 - 2025 (New and Old Top Songs 2000-2025)",
        videoId = "MoZhDn2k4zQ"
    },
    {
        title = "Revive Music - Top Hits 2026 ~ Trending Songs 2026 ~ Top Songs 2026 Top Music 🎶🎧",
        videoId = "fTKqtvXjkvo"
    },
    {
        title = "Slow Acoustic - Spotify Pop Hits 2026 ♫ Lady Gaga, Bruno Mars, Ed Sheeran, Billie Eilish, Miley Cyrus, Tate McRae#13",
        videoId = "WBy8ETk_Fqs"
    },
    {
        title = "Tyla - Tyla - SHE DID IT AGAIN (Official Music Video) ft. Zara Larsson",
        videoId = "rtwpk9rb1Dc"
    },
    {
        title = "Bruno Mars - Bruno Mars - I Just Might [Official Music Video]",
        videoId = "mrV8kK5t0V8"
    },
    {
        title = "Ngopi Dulu - Trending POP MUSIC 2026 🔥 Billboard Top 100 (No Ads)",
        videoId = "XV4dISvR4DI"
    },
    {
        title = "Billboard Beats - Adele, Taylor Swift, The Weeknd, Maroon 5, Lady Gaga, Ed Sheeran, Rihanna - Billboard 2026 Playlist",
        videoId = "AjQOB5XZcOE"
    },
    {
        title = "Billboard Beats - Adele, Taylor Swift, Rihanna, Ariana Grande, Bruno Mars, Maroon 5 🌊 Billboard Top 50 This Week 2026",
        videoId = "7vDO1zsKQN0"
    },
    {
        title = "PulsePlanetCharts - US Hot 100 Top Singles This Week + Bubbling Under Hot 100 (May 2nd, 2026)",
        videoId = "xr7-dNwyVxg"
    },
    {
        title = "Moonlight Chill Vibes - Top Pop Hits 2026 🍬🎧 Billboard Top 100 🔥 Taylor Swift, Justin Bieber, Bruno Mars, Adele, The Weeknd",
        videoId = "KKFubczfTOs"
    },
    {
        title = "ChartExpress - Billboard Hot 100 Single Charts | Top 100 | May 02, 2026 | ChartExpress #billboardcharts #hot100",
        videoId = "UchOs_Bh2DA"
    },
    {
        title = "Billboard News - Billboard Hot 100 Top 10 Countdown For May 2nd 2026 | Billboard News",
        videoId = "ZP-hy2emxHI"
    },
    {
        title = "Charted Music Plus - Final Predictions | Billboard Hot 100, Top 20 Singles | May 2nd, 2026",
        videoId = "kZ7K0UA4bpc"
    },
    {
        title = "Trending Songs 2026 - Billboard Hot 100 This Week 💥 Bruno Mars, Selena Gomez, Dua Lipa, Adele, Maroon 5, Ed Sheeran, Zayn",
        videoId = "18_ObnwdXqE"
    },
    {
        title = "ChartExpress - Billboard Hot 100 Single Charts | Top 100 | January 24, 2026 | ChartExpress",
        videoId = "PP4lo9B1crk"
    },
    {
        title = "Pure Tracks - Top Songs Cover 2026 🎙️ Hot Hit Music Pop Playlist ✨Pure Tracks",
        videoId = "k5jAV3VHr_4"
    },
    {
        title = "Deep Horizon - Spotify Playlist 2026 🎧 New Songs 2026 🎶 Trending Hits 2026 - Best Viral Songs Mix Hits",
        videoId = "N-er9BYmRrE"
    },
    {
        title = "Deep Horizon - Top Hits 2026 ~ Trending Music 2026 🎶 Spotify Hits 2026 ~ Top Songs 2026 🎧",
        videoId = "Uch3e4CI5dE"
    },
    {
        title = "JsVibes Music - Top Trending Spotify 2026🤎🟢~ Best Healing English Songs 2026 || Viral Spotify and Tiktok Songs",
        videoId = "-wsRxoto9h0"
    },
    {
        title = "Chill Pop Sunset - Top Hits 2026 ~ Trending Music 2026 🎶 Spotify Hits 2026 ~ Top Songs 2026 Top Music",
        videoId = "jnLljy-B05I"
    },
    {
        title = "Dynamic Deep House - Top Hits 2026 Playlist 🎧 Latest Top Songs 2026 🎧 Spotify Playlist 2026 🎶 Pop Music 2026",
        videoId = "2bk8UxQew2M"
    },
    {
        title = "Trending Songs 2026 - Pop Song 2026 ✨ Bruno Mars, Adele, Dua Lipa, Ed Sheeran, Selena Gomez, Maroon 5, Taylor Swift",
        videoId = "gJ5DrhLNgDg"
    },
    {
        title = "Dynamic Deep House - Top Hits 2026 Playlist ~ Trending Music 2026 🎵 Spotify Mix ~ Best TikTok Songs (Hits Collection)",
        videoId = "LuzXr3He9NI"
    },
    {
        title = "Deep Horizon - Top Spotify Hits 2026 🔥 Lady Gaga, Bruno Mars, Ed Sheeran, Ava Max, Taylor Swift, The Weeknd, Adele",
        videoId = "QFhYrD9eY2o"
    },
    {
        title = "PopWave Hits - Top Songs Cover HotHit Pop Playlist 🎙✨ 2026 | Velu Music Vol.4",
        videoId = "BhW6knhgwfQ"
    },
    {
        title = "Just Chillin' - Best Summer Songs 2026 🍒 Summer Hits 2026 Playlist",
        videoId = "97K9ByldojI"
    },
    {
        title = "VELU MUSIC - Top20.  Top Song Cover l Relax Hot Hit Music Pop Playlist Best Song  🎙✨  2026 | Velu Music  Vol.1",
        videoId = "6s7ToKF2-v0"
    },
    {
        title = "Acoustic Anna - Viral Spotify Song 2026🔥🎵| Newest English Love Song That Hit Deep | Soft Acoustic Playlist",
        videoId = "rIt4pBtu0QA"
    },
    {
        title = "DJ Khaled - DJ Khaled, Future, Lil Baby - One of Them (Official Music Video)",
        videoId = "7gKpREE5Z3w"
    },
    {
        title = "Pure Tracks - Top Hits 2026 🎙️ Top Songs Hot Hit Music Pop Playlist ✨ Pure Tracks",
        videoId = "rPtxYOyAUKc"
    },
    {
        title = "Dynamic Deep House - Top Hits 2026 🍒 Trending Music 2026 ~ TikTok & Spotify Viral Hits 🎧 Best Songs 2026 Updated Weekly",
        videoId = "lJAIdl7SipU"
    },
    {
        title = "T.I. - T.I. - LET 'EM KNOW (Official Video)",
        videoId = "mcg4z1gGbEw"
    },
    {
        title = "Diamond Platnumz and JUX - Diamond Platnumz ft Jux - JOY (Ikweji) Official Music Video",
        videoId = "XTLh3XZeVs4"
    },
    {
        title = "Serenata - New OPM Trending 2026 🎧 Tagalog Love Songs With Lyrics | Songs Everyone Loves",
        videoId = "7NQYmIycWj4"
    },
    {
        title = "Infinity EDM Mix - Music Mix 2026 | Party Club Dance 2026 | Best Remixes Of Popular Songs 2026 MEGAMIX",
        videoId = "zgunMW710rA"
    },
    {
        title = "Jassa Dhillon - Still In Love (Official Video) | Jassa Dhillon | New Punjabi Songs 2026",
        videoId = "sLueqNhgB3E"
    },
    {
        title = "West Coast Finest - Lit Hip Hop Mix 2026🔥🔥🔥Tyga, Quavo, Iggy Azalea, Wiz Khalifa, Juicy J, 50 Cent",
        videoId = "ZUExyc50ZVU"
    },
    {
        title = "Cloudmoon Sound - Pop Musics 2026 ♫ Bruno Mars, Lady Gaga, Dua Lipa, Adele, Ed Sheeran, The Weeknd ♫ Best playlist2026",
        videoId = "Wg9i_-H4Ol0"
    },
    {
        title = "Sabrina Carpenter - Sabrina Carpenter - House Tour (Official Video)",
        videoId = "KWoTyfPsqbE"
    },
    {
        title = "Nail Will - Viral Music 2026 🎶 Top Hits | Trending Songs",
        videoId = "sZ69g4xwKyE"
    },
    {
        title = "Jenn Muzic - Top Playlist 2026 🎵 | Chill & Good Vibes English Songs | Viral TikTok Mix",
        videoId = "wZMSetRxCMQ"
    },
    {
        title = "West Coast Finest - Rap Music 2025 - Hip Hop Playlist - Top Rap Songs 2025 Hip Hop Mix 🔥💸 Drake Kendrick Lamar Future",
        videoId = "7tLGfZWScwg"
    },
    {
        title = "West Coast Finest - Rap Music 2026 - Hip Hop Playlist - Top Rap Songs 2025 Hip Hop Mix 🔥💸 Drake Kendrick Lamar Future",
        videoId = "Nbi-DLhHt9k"
    },
    {
        title = "Revive Music - Rap Music 2025 - Hip Hop Playlist - Top Rap Songs 2025 Hip Hop Mix 🔥💸 Drake Kendrick Lamar Future",
        videoId = "IOO30CU6VmA"
    },
    {
        title = "DJ Noize - New Hip Hop R&B Songs 2026 Mix April | Hot Right Now #156 | New Rap 2026 Playlist | DJ Noize",
        videoId = "jAi8_fzgnFs"
    },
    {
        title = "DJ Noize - New Rap Songs 2026 Mix April | Trap Tape #131  | New Hip Hop 2026 Mixtape | DJ Noize",
        videoId = "4ZTICXBRmJk"
    },
    {
        title = "West Coast Finest - Rap Music 2026 - Hip Hop Playlist - Top Rap Songs 2025 Hip Hop Mix 🔥💸 Drake Kendrick Lamar Future",
        videoId = "4kQyZCiQLTA"
    },
    {
        title = "gentR - BEST RAP SONGS OF FEBRUARY 2026",
        videoId = "CVKvM3EebFI"
    },
    {
        title = "inteNsifyCharts - BEST RAP SONGS OF 2026 SO FAR! 🔥",
        videoId = "rGufvkfEtqY"
    },
    {
        title = "Moonlight Chill Vibes - Pop Music 2026🏖️🎧Top Viral Songs 🔥 Spotify Global Top 100 | Taylor Swift, The Weeknd, Justin Bieber",
        videoId = "b9UgMbshKis"
    },
    {
        title = "Moonlight Chill Vibes - 🌙🎧Eenie Meenie ~ Top Trending Spotify 2026🔥Justin Bieber, Bruno Mars, The Weeknd | Pop Hits Playlist",
        videoId = "uuP1duRrL6o"
    },
    {
        title = "Slow Acoustic - Top 20 Pop Songs 2026 ♫ Bruno Mars, Lady Gaga, Dua Lipa, Adele, Ed Sheeran, The Weeknd #30",
        videoId = "srkoDHDXSiU"
    },
    {
        title = "Revive Music - Pop Music 2025 - Top Pop Songs 2025 - Billboard Top 100 🎧🔥 Justin Bieber Billie Eilish Miley Cyrus",
        videoId = "E0Y8OEo_zOc"
    },
    {
        title = "Flow State Records  - SZA feat. Tory Lanez - Take Your Time (Official Video) VEVO 2026",
        videoId = "evuvoONO1So"
    },
    {
        title = "DMJ FREE MUSIC - Car Bass Boosted🔊 Music (NFS Payback, The Run, Crew 2) Vevo Music Video Full HD🔥",
        videoId = "TargM3f2kB4"
    },
    {
        title = "Taylor Swift - Taylor Swift - The Fate of Ophelia (Official Music Video)",
        videoId = "ko70cExuzZM"
    },
    {
        title = "OMER DEEP - OMER DEEP - Medusa (Original Mix)",
        videoId = "48EFv1qCUqY"
    },
    {
        title = "Belinda - Belinda - Cursi De + | Live From Vevo Studios",
        videoId = "kUj4SP43kS0"
    },
    {
        title = "Demi Lovato - Demi Lovato - Here All Night (Official Music Video)",
        videoId = "AeJZe6eHBEA"
    },
    {
        title = "Maroon 5 - Maroon 5, LISA - Priceless",
        videoId = "vaGf8fmtBr4"
    },
    {
        title = "Ciara - Ciara, Tyga - Dance With Me (Official Music Video)",
        videoId = "tGLuMoaVG1E"
    },
    {
        title = "Zara Larsson - Zara Larsson - Pretty Ugly (Official Music Video)",
        videoId = "Paddtn5IdCk"
    },
    {
        title = "Doja Cat - Doja Cat - Jealous Type (Official Video)",
        videoId = "lv1MwS56aCo"
    },
    {
        title = "Sabrina Carpenter - Sabrina Carpenter - Manchild (Official Video)",
        videoId = "aSugSGCC12I"
    },
    {
        title = "Tyla - Tyla - IS IT (Official Music Video)",
        videoId = "SZpiiixlHWY"
    },
    {
        title = "Ciara - Ciara, Diamond Platnumz - Low (Official Music Video)",
        videoId = "LBdAQaV1oQo"
    },
    {
        title = "Zara Larsson - Zara Larsson - Midnight Sun (Official Music Video)",
        videoId = "uvY8fdgezLQ"
    },
    {
        title = "Lady Gaga - Lady Gaga - Abracadabra (Official Music Video)",
        videoId = "vBynw9Isr28"
    },
    {
        title = "Tate McRae - Tate McRae - Revolving door (Official Video)",
        videoId = "rwlFWWGaZ5Y"
    },
    {
        title = "rauhlren - Justin Bieber - DAISIES (Music Video)",
        videoId = "QyvREl7epGY"
    },
    {
        title = "FOLA - FOLA - you (Official Video)",
        videoId = "Ra1yHDcJygY"
    },
    {
        title = "Cardi B - Cardi B - Safe (feat. Kehlani) [Official Music Video]",
        videoId = "E_0y8bmIATM"
    },
    {
        title = "Lady Gaga and Doechii - Lady Gaga, Doechii - RUNWAY (Official Music Video)",
        videoId = "XXIX2WnfbpE"
    },
    {
        title = "Olivia Rodrigo - Olivia Rodrigo - drop dead (Official Music Video)",
        videoId = "78wrful9cVU"
    },
    {
        title = "sonybeatz records - Rihanna - Kasongo Africa(2026 Official Afro Music Video)",
        videoId = "jcmq3Kmw56E"
    },
    {
        title = "Anette Aghabekyan and Аршавир Мартиросян - Anette Aghabekyan & Arshavir Martirosyan - Erkusov / Երկուսով (Official Music Video 2026)",
        videoId = "_8CkmnTH6M0"
    },
    {
        title = "Akon and Ochok - Akon - Que Calor (ft. Ochok) Official Music Video",
        videoId = "Wbo6N8AnVl4"
    },
    {
        title = "Meghan Trainor - Meghan Trainor - Shimmer (Official Music Video)",
        videoId = "VBqUGKcAfNA"
    },
    {
        title = "VybzKartelRadio - Vybz Kartel - 2026 (Official Music Video)",
        videoId = "RetXTfsEawE"
    },
    {
        title = "WaterTower Music - Techno Syndrome 2026 (feat. Ed Boon) - Official Music Video | Mortal Kombat II | WaterTower Music",
        videoId = "qZ58jpw2H0w"
    },
    {
        title = "Anyma and LLOUD Official - Anyma, LISA - Bad Angel (Official Music Video)",
        videoId = "dKmPEhJ4wjY"
    },
    {
        title = "Harry Styles - Harry Styles - American Girls (Official Video)",
        videoId = "o6jQo3-iCao"
    },
    {
        title = "Bruno Mars - Bruno Mars - Risk It All [Official Music Video]",
        videoId = "lY5V4hSLWY8"
    },
    {
        title = "Timeless Music Hits and Soft Rock Classics - Top 100 Songs of All Time 🎶 Greatest Hits That Defined Music History | Best Hits Playlist 2000 💿2025",
        videoId = "MIwp4KKugSs"
    },
    {
        title = "Revive Music - Top Hits 2025 ~ Top Music Playlist 2025 ~ Top Songs 2025 🎶🎧",
        videoId = "vp2ZoXIFJfw"
    },
    {
        title = "Slow Acoustic - Top 20 Pop Songs 2025 ♫ Bruno Mars, Lady Gaga, Dua Lipa, Adele, Ed Sheeran, The Weeknd #18",
        videoId = "-CXDKsZY80I"
    },
    {
        title = "Sunset Playlist - Spotify Pop Hits 2025 🔥 Lady Gaga, Bruno Mars, Ed Sheeran, Billie Eilish, Miley Cyrus, Tate McRae #1",
        videoId = "nXeEQTnfljo"
    },
    {
        title = "Global Records - Top 50 Global Hit List 💃🏻 Best Dance Songs 2025",
        videoId = "Cx-VVL5ZO8s"
    },
    {
        title = "melodyspot - 🎵 Best Songs 2025 Playlist 🎧 Melodyspot | Top US UK Hits & Trending Music VOL.2",
        videoId = "6CVjdRGG92Q"
    },
    {
        title = "Trending Songs 2026 - Dua Lipa, Bruno Mars, Adele, Ed Sheeran, Maroon 5, Rihanna, The Weeknd 💎 Billboard Top 50 This Week",
        videoId = "njsVjBYjjUM"
    },
    {
        title = "TOKYO GOD - TOP 50 MOST VIRAL PHONK/FUNK 2026 SONGS 🎵 PLAYLIST 🎵",
        videoId = "eARvryCElKU"
    },
    {
        title = "Dj Silviu M Official - Music Mix 2026 #50 Party Club Dance 2026 | Best Remixes Of Popular Songs 2025 MEGAMIX (DJ Silviu M)",
        videoId = "F5adyv2Grd8"
    },
    {
        title = "Slow Acoustic - Top 20 Pop Songs 2026 ♫ Bruno Mars, Lady Gaga, Dua Lipa, Adele, Ed Sheeran, The Weeknd #28",
        videoId = "eV5pzC43kQQ"
    },
    {
        title = "Rave Music Charts - Billboard Hot 100 | Top 10 Chart History | (2025)",
        videoId = "FezaUkaBk0k"
    },
    {
        title = "Top50Singles and Top50Singles+ - Billboard Hot 100 - Top 100 Singles of 2025 (Year-End Chart)",
        videoId = "EpFbFmIryfw"
    },
    {
        title = "DJ Sid Official - Top 100 Songs of 2025 - Billboard Year End",
        videoId = "eTIEv-Dfej4"
    },
    {
        title = "vamperys - Billboard Hot 100 Top 10 Songs | 2025 Full Chart History",
        videoId = "3Gq2yKMa9oI"
    },
    {
        title = "Billboard Chart Videos - Billboard Official Year-End Hot 100 Songs for 2025",
        videoId = "UUwQkUKrGao"
    },
    {
        title = "ChartExpress - Billboard Year-End 2025 | Hot 100 Songs | Top 100 | ChartExpress #billboard #yearendcharts",
        videoId = "ZpdyHm3n8gg"
    },
    {
        title = "DJ Sid Official - Top 100 Songs of 2025 (Excluding Christmas Songs) - Billboard Year End",
        videoId = "SzFwd2L2QOA"
    },
    {
        title = "vamperys - Billboard Hot 100 Top 10 Songs | 2025 Chart History",
        videoId = "pBxfsFfQK3k"
    },
    {
        title = "Dynamic Deep House - Spotify VIRAL Music 2026 ~ Top Spotify Songs Mix 🎧 Trending Songs 2026 ~ Best Pop Hits Playlist 2026",
        videoId = "fGPSs1PLc9o"
    },
    {
        title = "AaronTheHipHopGuy - Most Streamed Songs Of ALL TIME",
        videoId = "cNsntw9rhCg"
    },
    {
        title = "Max Grabel - Songs We Couldn’t Escape in Summer 2025",
        videoId = "PqyY0Id01xc"
    },
    {
        title = "Revive Music - Top Hits 2025 ~ Summer Playlist 2025 ~ Top Songs 2025 🎶🎧",
        videoId = "Ki4EHQvOlrw"
    },
    {
        title = "Brett Wolkey - Top 5 most iconic songs past 2000 #unskippablesongs #pumpedupkicks",
        videoId = "rAQ8O0dmst4"
    },
    {
        title = "Soulfulpop - Songs That Get Stuck in Your Head 🗣️🔥",
        videoId = "cdTNj3y6G8I"
    },
    {
        title = "Music Maestro🎵 - 😍 Top 10 Songs of 2025 So Far #shorts",
        videoId = "eR6kM7R0WV8"
    },
    {
        title = "Dream Music - Top 100 Songs 2024 -  Maroon 5, Ed Sheeran, Selena Gomez, Adele, The Weeknd, Dua Lipa",
        videoId = "7NgCf0TPgW8"
    },
    {
        title = "Acoustic Radio - Acoustic songs 2025 🌸 Music 2025 new songs with lyrics that last through love",
        videoId = "3ihtcnPwkqI"
    },
    {
        title = "Atus Music - PARTY MIX 2026 ⚡ Mashups & Remixes of Popular Songs 2026 ⚡ Tiësto, David Guetta, Hardwell, Afrojack",
        videoId = "XqbGEg1fhWU"
    },
    {
        title = "Tyla - Tyla - PUSH 2 START (Official Music Video)",
        videoId = "uLK2r3sG4lE"
    },
    {
        title = "Billie Eilish - Billie Eilish - BIRDS OF A FEATHER (Official Music Video)",
        videoId = "V9PVRfjEBTI"
    },
    {
        title = "Shaboozey - Shaboozey - A Bar Song (Tipsy) [Official Visualizer]",
        videoId = "t7bQwwqW-Hc"
    },
    {
        title = "Shenseea - Shenseea - Hit & Run ft. Masicka, Di Genius",
        videoId = "rJwEphsNVH8"
    },
    {
        title = "Shawn Mendes - Shawn Mendes - Why Why Why (Official Music Video)",
        videoId = "0M1UCYRZAtM"
    },
    {
        title = "Sweet Acoustic Music - Best Acoustic Songs 2024 🍓 Top Chill Love Songs Cover 2024 🍓 Soft Acoustic Love Songs",
        videoId = "5gljAOM5zsQ"
    },
    {
        title = "Best HipHop Music - HipHop Mix 2025 and RnB Mix 2025 - R&B HipHop Music 2025",
        videoId = "Re5Wc007Rts"
    },
    {
        title = "DJ Noize - 🔥 Hot Right Now - Best of 2024 | Best Hip Hop R&B Rap Songs of 2024 | New Year 2025 Mixtape",
        videoId = "--CKzGfPWn0"
    },
    {
        title = "Beatstorm - Rick Ross - Hard Times (Ft. Jeezy & Boosie Badazz) [Music Video] 2024",
        videoId = "pU22U6Kb1Zg"
    },
    {
        title = "Lil Baby Official  - Lil Baby -  By Myself Feat Rod Wave & Rylo Rodriguez (Official Music Video)",
        videoId = "Pw5y13LU_M0"
    },
    {
        title = "boogiehead - top songs of 2024",
        videoId = "Xi3cMZCcSXE"
    },
    {
        title = "Why not - Top 100 Songs 2024 - Maroon 5, Ed Sheeran, Selena Gomez, Adele, The Weekend, Dua Lipa",
        videoId = "U-l7OholHIU"
    },
    {
        title = "Love Life Lyrics - Top songs 2024 🍰 Best trending music 2024 ~ Songs that make you dance",
        videoId = "xLgRlJSgMh4"
    },
    {
        title = "Helios Deep - Mega Hits 2024 🌱 The Best Of Vocal Deep House Music Mix 2024 🌱 Summer Music Mix 2024 #205",
        videoId = "NqDGkdDh8WE"
    },
    {
        title = "Top Hits Music - Ed Sheeran, Rihanna, Selena Gomez, Bruno Mars, Maroon 5, Zayn, Adele, Dua Lipa 💎 Billboard Hot 100",
        videoId = "dDL3Ljvs1F4"
    },
    {
        title = "Royal Music 86 - Ed Sheeran Playlist 2024 - Best Songs Collection Full Album - The Best Of Ed Sheeran - Greatest Hits",
        videoId = "j4VQb3b_3Gc"
    },
    {
        title = "Deep Legends - Mega Hits 2024 🌱 The Best Of Vocal Deep House Music Mix 2024 🌱 Summer Music Mix 2024 #3",
        videoId = "iooiQGGSn4E"
    },
    {
        title = "Nemo - As 30 Melhores Músicas Pop 2025 🎧 Top Hits em Inglês 🎶 As Músicas Pop Mais Escutadas em 2025",
        videoId = "GJe2S_sxY1c"
    },
    {
        title = "Rave Music Charts - Billboard Hot 100 | Top 10 Chart History | (2024)",
        videoId = "SAJ_-wO6_FU"
    },
    {
        title = "DJ Sid Official - Top 100 Songs of 2024 - Billboard Year End",
        videoId = "yB49pFaS_As"
    },
    {
        title = "Top50Singles - Billboard Hot 100 - Top 100 Singles of 2024 (Year-End Chart)",
        videoId = "9jQUa3LYS2Y"
    },
    {
        title = "MrBreast - [COMPLETE] 2024 Billboard Hot 100 Top Ten - Chart History | + Streaming, Sales & Radio",
        videoId = "IvljZ2Xs1yg"
    },
    {
        title = "Top Songs 2025 - Top Songs 2024 🔥 New Popular Songs 2024 🔥 Top 100 Billboard Hot This Week 💖 Best English Songs 2024",
        videoId = "EI8t8OY67aU"
    },
    {
        title = "Rave Music Charts - Highest Point Peaks in One Week | Billboard Hot 100 Chart History (2024)",
        videoId = "pr5xyoaCpTE"
    },
    {
        title = "BB Chart Watcher - Billboard Hot 100 | Week of December 14th, 2024",
        videoId = "J3Jd9Gn14zU"
    },
    {
        title = " TOP Songs  2024  - TOP 100 Songs of 2024 - Billboard Hot 100 - Best Pop Music Playlist on Spotify 2024",
        videoId = "A8g9Z9oWDxI"
    },
    {
        title = "TradingViеw - Top 40 Songs of 2022 2023 - Billboard Hot 100 This Week - Best Pop Music Playlist on Spotify 2023",
        videoId = "KNaCJYX-mgY"
    },
    {
        title = "AIM Track - BILLBOARD HOT 100 This Week 🔥 Viral Songs 2026 | Bruno Mars, The Weeknd, Adele, Rihanna, Ed Sheeran",
        videoId = "SIUmZs_2bzs"
    },
    {
        title = "Camila Cabello - Camila Cabello - GODSPEED | Vevo Official Live Performance",
        videoId = "ZICJOhAjgi4"
    },
    {
        title = "Akon - Akon - Akon's Beautiful Day | Vevo ctrl",
        videoId = "4VdSG0YlPOY"
    },
    {
        title = "Chappell Roan - Chappell Roan - Red Wine Supernova (Live) | Vevo DSCVR Artists to Watch 2024",
        videoId = "uMshgHF9Gso"
    },
    {
        title = "Lady Gaga - Lady Gaga, Bruno Mars - Die With A Smile (Official Music Video)",
        videoId = "kPa7bsKwL-c"
    },
    {
        title = "HernandzMusic - Loreen  - Tattoo (Cover By Hernandz) (Official Music Video)",
        videoId = "F_IRCsyGUYc"
    },
    {
        title = "Jennifer Lopez - Jennifer Lopez & Maluma – Pa' Ti + Lonely (Official Video)",
        videoId = "A1kuaEuLX78"
    },
    {
        title = "Bruno Mars - Bruno Mars - 24K Magic (Official Music Video)",
        videoId = "UqyT8IEBkvY"
    },
    {
        title = "Taylor Swift - Taylor Swift - Anti-Hero (Official Music Video)",
        videoId = "b1kbLwvqugk"
    },
    {
        title = "OBZII OFFICIAL MUSIC - Obzii - Love Potion (Official Music Video) 2024",
        videoId = "NkjGK0We-Sw"
    },
    {
        title = "TraYan - TraYan - Крадена любов vol.2 / Kradena lyubov vol.2 (Official Music Video) 2024",
        videoId = "Faxkp-XvhkU"
    },
    {
        title = "Yemi Alade - Yemi Alade - Johnny (Official Music Video)",
        videoId = "C_XkTKoDI18"
    },
    {
        title = "Roddy Ricch - Roddy Ricch - The Box [Official Music Video]",
        videoId = "UNZqm3dxd2w"
    },
    {
        title = "Ncp Records - Necip - \" Bulka Na Godinata \" / \" Булка на годината \" (Official Music Video), 2024",
        videoId = "jFR-b3gJ6Mg"
    },
    {
        title = "APDHILLON - AP Dhillon ft. Ayra Starr - Bora Bora (Official Music Video) ft. Ayra Starr",
        videoId = "xARHpBzxFNI"
    },
    {
        title = "KIDZ BOP - 45 Minutes of your Favorite Music Videos! Featuring Dance Monkey, abc, As It Was and more!",
        videoId = "A1KmkM0wMmg"
    },
    {
        title = "Dua Lipa - Dua Lipa - New Rules (Official Music Video)",
        videoId = "k2qgadSvNyU"
    },
    {
        title = "EDM Party - DJ SONGS 2024 🔥 Mashups & Remixes Of Popular Songs 🔥 DJ Remix Club Music Dance Mix 2024",
        videoId = "6rfaoMvpry4"
    },
    {
        title = "Love Life Lyrics - Best songs that make you dance 2024 🍧 Dance playlist 2024 ~ Songs to sing & dance",
        videoId = "Db63h6RQEbE"
    },
    {
        title = "DJ LANCE THE MAN - Best of Rap & Hip Hop Essentials Video Mix (Drake, Lil Durk, Gunna, Chris Brown) - DJ LANCE THE MAN",
        videoId = "sqndlsVokKQ"
    },
    {
        title = "DJ Noize - Best Rap Songs 2024 | Best of 2024 Hip Hop Mix | Trap Tape | New Year 2025 Mix | DJ Noize Mixtape",
        videoId = "mbu8eEG6-k8"
    },
    {
        title = "inteNsifyCharts - BEST Rap Songs of 2024! 🔥",
        videoId = "blgIpixOvg4"
    },
    {
        title = "inteNsifyCharts - TOP 100 RAP SONGS OF 2024! (FAN CHOICES)",
        videoId = "o9uG_BLRHr8"
    },
    {
        title = "Fiscoos elevated music opinions  - BIGGEST Rap Song Every Month of 2024 #21savage #kendricklamar #kanyewest #drake #2024",
        videoId = "wL7Cx0P9DhI"
    },
    {
        title = "DJ Noize - 🔥 Hot Right Now - Best of 2023 | Best Hip Hop R&B Rap Songs of 2023 | New Year 2024 Mix",
        videoId = "XZOWcZZNZBs"
    },
    {
        title = "RapTunes - HipHop 2024 🔥 HipHop & Rap Party Mix 2024 - Top Rap Songs 2024",
        videoId = "g5q8t8rdr4M"
    },
    {
        title = "Hanumankind - Hanumankind, Kalmi - Hanumankind – Big Dawgs | Prod. Kalmi (Official Music Video) | Def Jam India",
        videoId = "hOHKltAiKXQ"
    },
    {
        title = "AaronTheHipHopGuy - Most Streamed Songs Of 2024",
        videoId = "9iXjKu3m_Fw"
    },
    {
        title = "inteNsifyCharts - From 2020 to 2024 - BEST Rap Songs Of This Decade",
        videoId = "C2SUD5HsnF0"
    },
    {
        title = "AaronTheHipHopGuy - The Most Streamed Rap Songs Of 2024 #rap #hiphop #kendricklamar #metroboomin #playboicarti #21savage",
        videoId = "ztMjGa8U4-k"
    },
    {
        title = "Delvin's Rhythmic Rift - TOP 10 BEST RAP SONGS OF 2024 #rapsongs #2024 #kendricklamar #drake",
        videoId = "c35qAyX025A"
    },
}
