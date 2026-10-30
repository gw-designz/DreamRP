Config = Config or {}

Config.Webhook = ""

Config.AllowedCrypto = {
    ["EXAMPLE_CRYPTO"] = true,
}

-- If true, all members of the group will receive splitted reward. If false, only the contract owner will receive the money/crypto reward.
Config.CurrencyForAllMembers = false

Config.Invitation = {
    Enabled = true,
    DistanceCheck = 100.0, -- Max distance between inviter and invitee for the invitation to be valid, set to nil to disable it
    ItemCheck = true,
}

Config.LevelForClass = {
    ["D"] = 0,
    ["C"] = 10,
    ["B"] = 20,
    ["A"] = 30,
    ["S"] = 55,
}

Config.LevelForVinScratchClass = {
    ["D"] = 0,
    ["C"] = 10,
    ["B"] = 20,
    ["A"] = 30,
    ["S"] = 55,
}

Config.VinScratchChance = {
    [10] = 0.01,
    [20] = 0.02,
    [30] = 0.05,
    [40] = 0.1,
    [50] = 0.15
}

Config.RequiredGroupSize = {
    ["D"] = 1,
    ["C"] = 1,
    ["B"] = 1,
    ["A"] = 3,
    ["S"] = 3,
}

Config.MaxGroupSize = {
    ["default"] = 5,
    ["D"] = 5,
    ["C"] = 5,
    ["B"] = 5,
    ["A"] = 5,
    ["S"] = 5,
}

Config.AddGroupPoints = {
    ["default"] = {
        exp = 650,
    },
    ["X"] = {
        exp = 650,
    },
    ["S"] = {
        exp = 650,
    },
    ["A"] = {
        exp = 650,
    },
    ["B"] = {
        exp = 650,
    },
    ["C"] = {
        exp = 650,
    },
    ["D"] = {
        exp = 650,
    },
}

Config.PrestigeLevel = 25

Config.MissionCancelCooldown = 30 * 60 -- 5 minutes

-- D - 15 - 25
-- C - 60 - 80
-- B - 130 - 155
-- A - 200 - 225
-- S - 280 - 300

Config.UnlockTimer = 4 * 60 * 60 -- 4 hours
Config.UnlockDrops = {
    ['D'] = {
        weight = 2,
        rewards = {
            amount = {5000, 10000},
            experience = {20, 33},
            cryptoName = "BANK",
        },
        drops = {
            start = {
                {
                    name = "steal_normal",
                    weight = 3,
                },
                {
                    name = "steal_garage",
                    weight = 1,
                },
                {
                    name = "steal_towtruck",
                    weight = 2,
                    blockedNext = {
                        ["middle_hack"] = true,
                    }
                }
            },
            middle = {
                -- {
                --     name = "middle_hack",
                --     weight = 1,
                -- },
                {
                    name = "__EMPTY__",
                    weight = 5,
                },
                {
                    name = "middle_repaint",
                    weight = 5,
                    requiredNext = {
                        ["deliver_dropoff"] = true,
                    }
                }
            },
            deliver = {
                {
                    name = "deliver_dropoff",
                    weight = 4,
                },
                {
                    name = "deliver_container",
                    weight = 2,
                },
                {
                    name = "deliver_destroy",
                    weight = 1,
                },
                {
                    name = "deliver_chop",
                    weight = 8,
                },
            }
        }
    },
    ['C'] = {
        weight = 4,
        rewards = {
            amount = {15000, 20000},
            experience = {39, 78},
            cryptoName = "BANK",
        },
        drops = {
            start = {
                {
                    name = "steal_normal",
                    weight = 3,
                },
                {
                    name = "steal_signal",
                    weight = 2,
                },
                {
                    name = "steal_garage",
                    weight = 5,
                },
            },
            middle = {
                {
                    name = "middle_hack",
                    weight = 1,
                },
                {
                    name = "__EMPTY__",
                    weight = 7,
                },
                {
                    name = "middle_repaint",
                    weight = 1,
                    requiredNext = {
                        ["deliver_dropoff"] = true,
                    }
                },
                -- {
                --     name = "middle_hack_bomb",
                --     weight = 1,
                -- }
            },
            deliver = {
                {
                    name = "deliver_dropoff",
                    weight = 4,
                },
                {
                    name = "deliver_chop",
                    weight = 8,
                },
                {
                    name = "deliver_trailer",
                    weight = 2,
                },
                {
                    name = "deliver_container",
                    weight = 2,
                },
                {
                    name = "deliver_destroy",
                    weight = 1,
                },
                {
                    name = "deliver_dropoff_ransom",
                    weight = 1,
                },
            }
        }
    },
    ['B'] = {
        weight = 4,
        rewards = {
            amount = {25000, 30000},
            experience = {78, 156},
            cryptoName = "BANK",
        },
        drops = {
            start = {
                {
                    name = "steal_normal",
                    weight = 3,
                },
                {
                    name = "steal_valet",
                    weight = 1,
                },
                {
                    name = "steal_rental_fakeId",
                    weight = 2,
                },
                {
                    name = "steal_obd_hack",
                    weight = 3,
                },
                {
                    name = "steal_signal",
                    weight = 3,
                },
                {
                    name = "steal_garage",
                    weight = 2,
                },
            },
            middle = {
                {
                    name = "middle_hack",
                    weight = 7,
                },
                {
                    name = "middle_hack_bomb",
                    weight = 1,
                },
                {
                    name = "middle_hacker_van",
                    weight = 2,
                },
            },
            deliver = {
                {
                    name = "deliver_dropoff",
                    weight = 2,
                },
                {
                    name = "deliver_chop",
                    weight = 8,
                },
                {
                    name = "deliver_trailer",
                    weight = 1,
                },
                {
                    name = "deliver_container",
                    weight = 1,
                },
                {
                    name = "deliver_destroy",
                    weight = 1,
                },
                {
                    name = "deliver_cargoplane",
                    weight = 1,
                },
                {
                    name = "deliver_crusher",
                    weight = 1,
                },
                {
                    name = "deliver_dropoff_ransom",
                    weight = 1,
                },
            }
        }
    },
    ['A'] = {
        weight = 2,
        rewards = {
            amount = {35000, 40000},
            experience = {156, 260},
            cryptoName = "BANK",
        },
        drops = {
            start = {
                {
                    name = "steal_normal",
                    weight = 3,
                },
                {
                    name = "steal_villa",
                    weight = 1,
                },
                {
                    name = "steal_rental_fakeId",
                    weight = 2,
                },
                {
                    name = "steal_obd_hack",
                    weight = 3,
                },
                {
                    name = "steal_signal",
                    weight = 3,
                },
                {
                    name = "steal_cargobob",
                    weight = 1,
                },
            },
            middle = {
                {
                    name = "middle_hack",
                    weight = 4,
                },
                {
                    name = "middle_hack_bomb",
                    weight = 1,
                },
                {
                    name = "middle_hack_plantbomb",
                    weight = 1,
                },
                {
                    name = "middle_hacker_van",
                    weight = 3,
                },
                {
                    name = "middle_hack_mechanic",
                    weight = 1,
                }
            },
            deliver = {
                {
                    name = "deliver_dropoff",
                    weight = 2,
                },
                {
                    name = "deliver_trap",
                    weight = 2,
                },
                {
                    name = "deliver_dropoff_perfect",
                    weight = 3,
                },
                {
                    name = "deliver_buyer",
                    weight = 2,
                },
                {
                    name = "deliver_dropoff_ransom",
                    weight = 2,
                },
                {
                    name = "deliver_cargoplane",
                    weight = 2,
                },
                {
                    name = "deliver_chop",
                    weight = 5,
                },
            }
        }
    },
    ['S'] = {
        weight = 1,
        rewards = {
            amount = {54000, 66000},
            experience = {187, 312},
            cryptoName = "BANK",
        },
        drops = {
            start = {
                {
                    name = "steal_normal",
                    weight = 3,
                },
                {
                    name = "steal_villa",
                    weight = 1,
                },
                {
                    name = "steal_rental_fakeId",
                    weight = 2,
                },
                {
                    name = "steal_obd_hack",
                    weight = 3,
                },
                {
                    name = "steal_signal",
                    weight = 3,
                },
                {
                    name = "steal_cargobob",
                    weight = 1,
                },
            },
            middle = {
                {
                    name = "middle_hack",
                    weight = 4,
                },
                {
                    name = "middle_hack_bomb",
                    weight = 1,
                },
                {
                    name = "middle_hack_plantbomb",
                    weight = 1,
                },
                {
                    name = "middle_hacker_van",
                    weight = 3,
                },
                {
                    name = "middle_hack_mechanic",
                    weight = 1,
                }
            },
            deliver = {
                {
                    name = "deliver_dropoff",
                    weight = 2,
                },
                {
                    name = "deliver_trap",
                    weight = 2,
                },
                {
                    name = "deliver_dropoff_perfect",
                    weight = 3,
                },
                {
                    name = "deliver_buyer",
                    weight = 2,
                },
                {
                    name = "deliver_dropoff_ransom",
                    weight = 2,
                },
                {
                    name = "deliver_cargoplane",
                    weight = 2,
                },
                {
                    name = "deliver_chop",
                    weight = 5,
                },
            }
        }
    },
}

Config.UnlockDropsWeightsOverride = {
    [15] = {
        ['D'] = 2,
        ['C'] = 5,
        ['B'] = 2,
        ['A'] = 2,
        ['S'] = 1,
    },
    [30] = {
        ['D'] = 1,
        ['C'] = 1,
        ['B'] = 5,
        ['A'] = 2,
        ['S'] = 1,
    },
    [40] = {
        ['D'] = 1,
        ['C'] = 1,
        ['B'] = 3,
        ['A'] = 5,
        ['S'] = 1,
    },
    [55] = {
        ['D'] = 1,
        ['C'] = 1,
        ['B'] = 1,
        ['A'] = 3,
        ['S'] = 2,
    }
}

Config.LuxuryUnlockDropWeightsOverride = {
    [15] = {
        ['D'] = 2,
        ['C'] = 5,
        ['B'] = 3,
        ['A'] = 3,
        ['S'] = 1,
    },
    [30] = {
        ['D'] = 1,
        ['C'] = 1,
        ['B'] = 5,
        ['A'] = 3,
        ['S'] = 1,
    },
    [40] = {
        ['D'] = 1,
        ['C'] = 1,
        ['B'] = 4,
        ['A'] = 7,
        ['S'] = 1,
    },
    [55] = {
        ['D'] = 1,
        ['C'] = 1,
        ['B'] = 1,
        ['A'] = 3,
        ['S'] = 4,
    }
}

Config.MarketGenerationInterval = 2 * 60 * 60 -- 2 hours
Config.MarketGeneration = {
    -- ['D'] = {
    --     weight = 5,
    --     rewards = {
    --         amount = {5, 10},
    --         experience = {20, 33},
    --         cryptoName = "RACE",
    --     },
    --     price = {1, 4},
    --     cryptoName = "BANK",
    --     drops = {
    --         start = {
    --             {
    --                 name = "steal_normal",
    --                 weight = 3,
    --             },
    --             {
    --                 name = "steal_garage",
    --                 weight = 1,
    --             },
    --             {
    --                 name = "steal_towtruck",
    --                 weight = 2,
    --             }
    --         },
    --         middle = {
    --             {
    --                 name = "__EMPTY__",
    --                 weight = 2,
    --             },
    --             {
    --                 name = "middle_repaint",
    --                 weight = 1,
    --                 requiredNext = {
    --                     ["deliver_dropoff"] = true,
    --                 }
    --             }
    --         },
    --         deliver = {
    --             {
    --                 name = "deliver_dropoff",
    --                 weight = 4,
    --             },
    --             {
    --                 name = "deliver_container",
    --                 weight = 2,
    --             },
    --             {
    --                 name = "deliver_destroy",
    --                 weight = 1,
    --             },
    --             {
    --                 name = "deliver_chop",
    --                 weight = 1,
    --             },
    --         }
    --     }
    -- },
    -- ['C'] = {
    --     weight = 4,
    --     rewards = {
    --         amount = {30, 50},
    --         experience = {25, 50},
    --         cryptoName = "RACE",
    --     },
    --     price = {10, 16},
    --     cryptoName = "BANK",
    --     drops = {
    --         start = {
    --             {
    --                 name = "steal_normal",
    --                 weight = 3,
    --             },
    --             {
    --                 name = "steal_signal",
    --                 weight = 2,
    --             },
    --             {
    --                 name = "steal_trailer",
    --                 weight = 5,
    --             },
    --             {
    --                 name = "steal_garage",
    --                 weight = 5,
    --             },
    --         },
    --         middle = {
    --             {
    --                 name = "__EMPTY__",
    --                 weight = 2,
    --             },
    --             {
    --                 name = "middle_repaint",
    --                 weight = 1,
    --                 requiredNext = {
    --                     ["deliver_dropoff"] = true,
    --                 }
    --             },
    --             {
    --                 name = "middle_hack_bomb",
    --                 weight = 1,
    --             }
    --         },
    --         deliver = {
    --             {
    --                 name = "deliver_dropoff",
    --                 weight = 4,
    --             },
    --             {
    --                 name = "deliver_chop",
    --                 weight = 5,
    --             },
    --             {
    --                 name = "deliver_trailer",
    --                 weight = 2,
    --             },
    --             {
    --                 name = "deliver_container",
    --                 weight = 2,
    --             },
    --             {
    --                 name = "deliver_destroy",
    --                 weight = 1,
    --             },
    --             {
    --                 name = "deliver_dropoff_ransom",
    --                 weight = 1,
    --             },
    --         }
    --     }
    -- },
    ['B'] = {
        weight = 5,
        rewards = {
            amount = {4000, 6000},
            experience = {78, 156},
            cryptoName = "BANK",
        },
        price = {2000, 3000},
        cryptoName = "BANK",
        drops = {
            start = {
                {
                    name = "steal_normal",
                    weight = 3,
                },
                {
                    name = "steal_valet",
                    weight = 1,
                },
                {
                    name = "steal_rental_fakeId",
                    weight = 2,
                },
                {
                    name = "steal_obd_hack",
                    weight = 3,
                },
                {
                    name = "steal_signal",
                    weight = 3,
                },
                {
                    name = "steal_garage",
                    weight = 2,
                },
            },
            middle = {
                {
                    name = "middle_hack",
                    weight = 7,
                },
                {
                    name = "middle_hack_bomb",
                    weight = 1,
                },
                {
                    name = "middle_hacker_van",
                    weight = 2,
                },
            },
            deliver = {
                {
                    name = "deliver_dropoff",
                    weight = 2,
                },
                {
                    name = "deliver_chop",
                    weight = 5,
                },
                {
                    name = "deliver_trailer",
                    weight = 1,
                },
                {
                    name = "deliver_container",
                    weight = 1,
                },
                {
                    name = "deliver_destroy",
                    weight = 1,
                },
                {
                    name = "deliver_cargoplane",
                    weight = 1,
                },
                {
                    name = "deliver_crusher",
                    weight = 1,
                },
                {
                    name = "deliver_dropoff_ransom",
                    weight = 1,
                },
            }
        }
    },
    ['A'] = {
        weight = 5,
        rewards = {
            amount = {35000, 40000},
            experience = {156, 260},
            cryptoName = "BANK",
        },
        price = {2500, 3000},
        cryptoName = "BANK",
        drops = {
            start = {
                {
                    name = "steal_normal",
                    weight = 3,
                },
                {
                    name = "steal_valet",
                    weight = 1,
                },
                {
                    name = "steal_rental_fakeId",
                    weight = 2,
                },
                {
                    name = "steal_obd_hack",
                    weight = 3,
                },
                {
                    name = "steal_signal",
                    weight = 3,
                },
                {
                    name = "steal_garage",
                    weight = 2,
                },
            },
            middle = {
                {
                    name = "middle_hack",
                    weight = 7,
                },
                {
                    name = "middle_hack_bomb",
                    weight = 1,
                },
                {
                    name = "middle_hacker_van",
                    weight = 2,
                },
            },
            deliver = {
                {
                    name = "deliver_dropoff",
                    weight = 2,
                },
                {
                    name = "deliver_chop",
                    weight = 5,
                },
                {
                    name = "deliver_trailer",
                    weight = 1,
                },
                {
                    name = "deliver_container",
                    weight = 1,
                },
                {
                    name = "deliver_destroy",
                    weight = 1,
                },
                {
                    name = "deliver_cargoplane",
                    weight = 1,
                },
                {
                    name = "deliver_crusher",
                    weight = 1,
                },
                {
                    name = "deliver_dropoff_ransom",
                    weight = 1,
                },
            }
        }
    },
}

Config.VinScratchGeneration = {
    ['D'] = {
        weight = 5,
        rewards = {
            amount = {5000, 10000},
            experience = {20, 33},
            cryptoName = "BANK",
        },
        price = {1000, 4000},
        prereqCount = {1, 1},
        drops = {
            prereqs = {
                {
                    name = "pre_bring_boosting_pdm_key",
                    weight = 1,
                },
            },
            start = {
                {
                    name = "steal_normal",
                    weight = 3,
                },
                {
                    name = "steal_garage",
                    weight = 1,
                },
                {
                    name = "steal_towtruck",
                    weight = 2,
                    blockedNext = {
                        ["middle_hack"] = true,
                    }
                }
            },
            middle = {
                {
                    name = "middle_hack",
                    weight = 1,
                },
                {
                    name = "__EMPTY__",
                    weight = 5,
                },
                {
                    name = "middle_repaint",
                    weight = 5,
                }
            },
            vinDeliver = {
                {
                    name = "vinDeliver_dropoff",
                    weight = 1,
                },
            }
        }
    },
    ['C'] = {
        weight = 4,
        rewards = {
            amount = {15000, 20000},
            experience = {39, 78},
            cryptoName = "BANK",
        },
        prereqCount = {2, 3},
        drops = {
            prereqs = {
                {
                    name = "pre_bring_boosting_pdm_key",
                    weight = 1,
                },
            },
            start = {
                {
                    name = "steal_normal",
                    weight = 3,
                },
                {
                    name = "steal_signal",
                    weight = 2,
                },
                {
                    name = "steal_garage",
                    weight = 5,
                },
            },
            middle = {
                {
                    name = "middle_hack",
                    weight = 9,
                },
                {
                    name = "__EMPTY__",
                    weight = 2,
                },
                {
                    name = "middle_repaint",
                    weight = 1,
                },
                {
                    name = "middle_hack_bomb",
                    weight = 1,
                }
            },
            vinDeliver = {
                {
                    name = "vinDeliver_dropoff",
                    weight = 1,
                },
            }
        }
    },
    ['B'] = {
        weight = 4,
        rewards = {
            amount = {25000, 30000},
            experience = {78, 156},
            cryptoName = "BANK",
        },
        prereqCount = {2, 3},
        drops = {
            prereqs = {
                {
                    name = "pre_bring_boosting_pdm_key",
                    weight = 1,
                },
                {
                    name = "pre_bring_boosting_jewelery_key",
                    weight = 1,
                },
            },
            start = {
                {
                    name = "steal_normal",
                    weight = 3,
                },
                {
                    name = "steal_valet",
                    weight = 1,
                },
                {
                    name = "steal_rental_fakeId",
                    weight = 2,
                },
                {
                    name = "steal_obd_hack",
                    weight = 3,
                },
                {
                    name = "steal_signal",
                    weight = 3,
                },
                {
                    name = "steal_garage",
                    weight = 2,
                },
            },
            middle = {
                {
                    name = "middle_hack",
                    weight = 7,
                },
                {
                    name = "middle_hack_bomb",
                    weight = 1,
                },
                {
                    name = "middle_hacker_van",
                    weight = 2,
                },
            },
            vinDeliver = {
                {
                    name = "vinDeliver_dropoff",
                    weight = 1,
                },
            }
        }
    },
    ['A'] = {
        weight = 1,
        rewards = {
            amount = {35000, 40000},
            experience = {156, 260},
            cryptoName = "BANK",
        },
        prereqCount = {2, 3},
        drops = {
            prereqs = {
                {
                    name = "pre_bring_boosting_pdm_key",
                    weight = 1,
                },
                {
                    name = "pre_bring_boosting_jewelery_key",
                    weight = 1,
                },
            },
            start = {
                {
                    name = "steal_normal",
                    weight = 3,
                },
                {
                    name = "steal_villa",
                    weight = 1,
                },
                {
                    name = "steal_rental_fakeId",
                    weight = 2,
                },
                {
                    name = "steal_obd_hack",
                    weight = 3,
                },
                {
                    name = "steal_signal",
                    weight = 3,
                },
                {
                    name = "steal_cargobob",
                    weight = 1,
                },
            },
            middle = {
                {
                    name = "middle_hack",
                    weight = 7,
                },
                {
                    name = "middle_hack_bomb",
                    weight = 1,
                },
                {
                    name = "middle_hack_plantbomb",
                    weight = 3,
                },
                {
                    name = "middle_hacker_van",
                    weight = 2,
                },
                {
                    name = "middle_hack_mechanic",
                    weight = 1,
                }
            },
            vinDeliver = {
                {
                    name = "vinDeliver_dropoff",
                    weight = 1,
                },
            }
        }
    },
    ['S'] = {
        weight = 1,
        rewards = {
            amount = {80000, 120000},
            experience = {187, 312},
            cryptoName = "BANK",
        },
        prereqCount = {2, 3},
        drops = {
            prereqs = {
                {
                    name = "pre_bring_boosting_pdm_key",
                    weight = 1,
                },
                {
                    name = "pre_bring_boosting_jewelery_key",
                    weight = 1,
                },
                {
                    name = "bring_boosting_bank_key",
                    weight = 1,
                }
            },
            start = {
                {
                    name = "steal_normal",
                    weight = 3,
                },
                {
                    name = "steal_villa",
                    weight = 1,
                },
                {
                    name = "steal_rental_fakeId",
                    weight = 2,
                },
                {
                    name = "steal_obd_hack",
                    weight = 3,
                },
                {
                    name = "steal_signal",
                    weight = 3,
                },
                {
                    name = "steal_cargobob",
                    weight = 1,
                },
            },
            middle = {
                {
                    name = "middle_hack",
                    weight = 7,
                },
                {
                    name = "middle_hack_bomb",
                    weight = 1,
                },
                {
                    name = "middle_hack_plantbomb",
                    weight = 3,
                },
                {
                    name = "middle_hacker_van",
                    weight = 2,
                },
                {
                    name = "middle_hack_mechanic",
                    weight = 1,
                }
            },
            vinDeliver = {
                {
                    name = "vinDeliver_dropoff",
                    weight = 1,
                },
            }
        }
    },
}

Config.NpcConfig = {
    ['A'] = {
        spawnChance = 75,
        weapons = {
            { weapon = `WEAPON_PISTOL`, weight = 20 },
            { weapon = `WEAPON_COMBATPISTOL`, weight = 20 },
            { weapon = `WEAPON_SMG`, weight = 20 },
            { weapon = `WEAPON_CARBINERIFLE`, weight = 20 },
            { weapon = `WEAPON_PUMPSHOTGUN`, weight = 20 },
        },
        models = {
            { model = `a_m_m_farmer_01`, weight = 50 },
            { model = `a_m_m_hillbilly_02`, weight = 50 },
        },
    },
    ['B'] = {
        spawnChance = 50,
        weapons = {
            { weapon = `WEAPON_PISTOL`, weight = 40 },
            { weapon = `WEAPON_COMBATPISTOL`, weight = 20 },
            { weapon = `WEAPON_SMG`, weight = 40 },
        },
        models = {
            { model = `a_m_m_farmer_01`, weight = 50 },
            { model = `a_m_m_hillbilly_02`, weight = 50 },
        },
    }, 
    ['C'] = {
        spawnChance = 25,
        weapons = {
            { weapon = `WEAPON_PISTOL`, weight = 80 },
            { weapon = `WEAPON_COMBATPISTOL`, weight = 20 },
        },
        models = {
            { model = `a_m_m_farmer_01`, weight = 50 },
            { model = `a_m_m_hillbilly_02`, weight = 50 },
        },
    },
}

Config.SharedLocations = {
    ["normal"] = {
        {
            coords = vec4(122.6, -129.9, 53.5, 68.0),
            locationLabel = "Southern Vinewood",
            npcLocations = {
                vec4(116.1, -131.4, 54.8, 25.8)
            }
        },
        {
            coords = vec4(-1532.9538574219, -432.56701660156, 34.789794921875, 48.188972473145),
            locationLabel = "Boulevard Del Perro",
            npcLocations = {
                vec3(-1533.922729, -434.316681, 34.789795),
                vec3(-1531.984985, -430.817352, 34.789795)
            }
        },
        {
            coords = vec4(-1509.5736083984, -435.13845825195, 34.806640625, 263.6220703125),
            locationLabel = "Boulevard Del Perro",
            npcLocations = {
                vec3(-1507.646973, -435.675232, 34.806641),
                vec3(-1511.500244, -434.601685, 34.806641)
            }
        },
        {
            coords = vec4(-1556.3472900391, -464.74285888672, 35.227783203125, 51.023624420166),
            locationLabel = "Boulevard Del Perro",
            npcLocations = {
                vec3(-1554.895020, -463.367706, 35.227783),
                vec3(-1557.799561, -466.118011, 35.227783)
            }
        },
        {
            coords = vec4(-1513.3582763672, -512.22857666016, 34.924560546875, 212.59841918945),
            locationLabel = "Boulevard Del Perro",
            npcLocations = {
                vec3(-1512.328491, -513.943054, 34.924561),
                vec3(-1514.388062, -510.514099, 34.924561)
            }
        },
        {
            coords = vec4(-1374.4615478516, -447.65274047852, 33.829345703125, 34.015747070312),
            locationLabel = "South Rockford Dr",
            npcLocations = {
                vec3(-1376.175171, -446.621429, 33.829346),
                vec3(-1372.747925, -448.684052, 33.829346)
            }
        },
        {
            coords = vec4(-1349.841796875, -458.74285888672, 33.1552734375, 218.2677154541),
            locationLabel = "North Rockford Dr",
            npcLocations = {
                vec3(-1349.987671, -460.737549, 33.155273),
                vec3(-1349.695923, -456.748169, 33.155273)
            }
        },
        {
            coords = vec4(-1332.4088134766, -483.44177246094, 32.7509765625, 218.2677154541),
            locationLabel = "North Rockford Dr",
            npcLocations = {
                vec3(-1332.554688, -485.436462, 32.750977),
                vec3(-1332.262939, -481.447083, 32.750977)
            }
        },
        {
            coords = vec4(-1178.0834960938, -423.90328979492, 33.896728515625, 226.77166748047),
            locationLabel = "Marathon Ave",
            npcLocations = {
                vec3(-1176.407227, -422.812286, 33.896729),
                vec3(-1179.759766, -424.994293, 33.896729)
            }
        },
        {
            coords = vec4(-1142.3077392578, -418.78680419922, 35.430053710938, 218.2677154541),
            locationLabel = "Marathon Ave",
            npcLocations = {
                vec3(-1142.453613, -420.781494, 35.430054),
                vec3(-1142.161865, -416.792114, 35.430054)
            }
        },
        {
            coords = vec4(-1039.4241943359, -388.11428833008, 37.1318359375, 308.97637939453),
            locationLabel = "Marathon Ave",
            npcLocations = {
                vec3(-1038.517578, -386.331604, 37.131836),
                vec3(-1040.330811, -389.896973, 37.131836)
            }
        },
        {
            coords = vec4(-974.61096191406, -341.22198486328, 36.9970703125, 348.6614074707),
            locationLabel = "Marathon Ave",
            npcLocations = {
                vec3(-976.607910, -341.111298, 36.997070),
                vec3(-972.614014, -341.332672, 36.997070)
            }
        },
        {
            coords = vec4(-929.16925048828, -317.05053710938, 38.564086914062, 249.44882202148),
            locationLabel = "Marathon Ave",
            npcLocations = {
                vec3(-929.775146, -318.956543, 38.564087),
                vec3(-928.563354, -315.144531, 38.564087)
            }
        },
        {
            coords = vec4(-868.68133544922, -221.02416992188, 38.783203125, 25.511812210083),
            locationLabel = "Mad Wayne Thunder Dr",
            npcLocations = {
                vec3(-866.823303, -220.284058, 38.783203),
                vec3(-870.539368, -221.764282, 38.783203)
            }
        },
        {
            coords = vec4(-896.69012451172, -63.956039428711, 37.485717773438, 17.007873535156),
            locationLabel = "Mad Wayne Thunder Dr",
            npcLocations = {
                vec3(-897.225281, -65.883110, 37.485718),
                vec3(-896.154968, -62.028973, 37.485718)
            }
        },
        {
            coords = vec4(-927.38903808594, 10.061539649963, 47.140625, 215.43309020996),
            locationLabel = "Mad Wayne Thunder Dr",
            npcLocations = {
                vec3(-927.852783, 12.007036, 47.140625),
                vec3(-926.925293, 8.116043, 47.140625)
            }
        },
        {
            coords = vec4(-696.27691650391, 42.118682861328, 42.557495117188, 116.22047424316),
            locationLabel = "Strangeways Dr",
            npcLocations = {
                vec3(-698.276550, 42.155590, 42.557495),
                vec3(-694.277283, 42.081776, 42.557495)
            }
        },
        {
            coords = vec4(-601.79339599609, 137.43296813965, 59.120849609375, 25.511812210083),
            locationLabel = "Spanish Ave",
            npcLocations = {
                vec3(-599.935364, 138.173080, 59.120850),
                vec3(-603.651428, 136.692856, 59.120850)
            }
        },
        {
            coords = vec4(-509.40658569336, 198.0, 70.292358398438, 357.16534423828),
            locationLabel = "Milton Rd",
            npcLocations = {
                vec3(-508.286255, 196.343231, 70.292358),
                vec3(-510.526917, 199.656769, 70.292358)
            }
        },
        {
            coords = vec4(-457.31866455078, 193.80659484863, 74.588989257812, 348.6614074707),
            locationLabel = "Eclipse Blvd",
            npcLocations = {
                vec3(-459.315613, 193.917297, 74.588989),
                vec3(-455.321716, 193.695892, 74.588989)
            }
        },
        {
            coords = vec4(-447.45495605469, 174.96264648438, 74.555297851562, 175.74803161621),
            locationLabel = "Spanish Ave",
            npcLocations = {
                vec3(-445.487671, 174.602310, 74.555298),
                vec3(-449.422241, 175.322983, 74.555298)
            }
        },
        {
            coords = vec4(-418.87911987305, 299.1428527832, 82.575805664062, 357.16534423828),
            locationLabel = "Didion Dr",
            npcLocations = {
                vec3(-417.758789, 297.486084, 82.575806),
                vec3(-419.999451, 300.799622, 82.575806)
            }
        },
        {
            coords = vec4(-417.52087402344, 287.49890136719, 82.575805664062, 184.25196838379),
            locationLabel = "Eclipse Blvd",
            npcLocations = {
                vec3(-418.424500, 289.283112, 82.575806),
                vec3(-416.617249, 285.714691, 82.575806)
            }
        },
        {
            coords = vec4(-329.1428527832, 277.68792724609, 85.676147460938, 99.212593078613),
            locationLabel = "Eclipse Blvd",
            npcLocations = {
                vec3(-328.643341, 275.751312, 85.676147),
                vec3(-329.642365, 279.624542, 85.676147)
            }
        },
        {
            coords = vec4(-315.78460693359, 230.05714416504, 86.956787109375, 294.80316162109),
            locationLabel = "Eclipse Blvd",
            npcLocations = {
                vec3(-314.035767, 229.086823, 86.956787),
                vec3(-317.533447, 231.027466, 86.956787)
            }
        },
        {
            coords = vec4(-250.43077087402, 288.87033081055, 91.15234375, 277.79528808594),
            locationLabel = "Eclipse Blvd",
            npcLocations = {
                vec3(-249.963791, 290.815063, 91.152344),
                vec3(-250.897751, 286.925598, 91.152344)
            }
        },
        {
            coords = vec4(-208.64175415039, 281.32748413086, 91.7421875, 161.57479858398),
            locationLabel = "Eclipse Blvd",
            npcLocations = {
                vec3(-209.072784, 279.374481, 91.742188),
                vec3(-208.210724, 283.280487, 91.742188)
            }
        },
        {
            coords = vec4(-145.4373626709, 242.22857666016, 94.10107421875, 263.6220703125),
            locationLabel = "Eclipse Blvd",
            npcLocations = {
                vec3(-143.510742, 241.691818, 94.101074),
                vec3(-147.363983, 242.765335, 94.101074)
            }
        },
        {
            coords = vec4(-59.05054473877, 218.09671020508, 105.91284179688, 161.57479858398),
            locationLabel = "Eclipse Blvd",
            npcLocations = {
                vec3(-59.481583, 216.143707, 105.912842),
                vec3(-58.619507, 220.049713, 105.912842)
            }
        },
        {
            coords = vec4(-29.854942321777, 209.39340209961, 105.91284179688, 167.24407958984),
            locationLabel = "Las Lagunas Blvd",
            npcLocations = {
                vec3(-31.332325, 208.045319, 105.912842),
                vec3(-28.377560, 210.741486, 105.912842)
            }
        },
        {
            coords = vec4(64.892311096191, 149.31428527832, 103.95825195312, 158.74015808105),
            locationLabel = "Las Lagunas Blvd",
            npcLocations = {
                vec3(64.713097, 151.306244, 103.958252),
                vec3(65.071526, 147.322327, 103.958252)
            }
        },
        {
            coords = vec4(155.19561767578, 182.18901062012, 105.01977539062, 340.15747070312),
            locationLabel = "Vinewood Blvd",
            npcLocations = {
                vec3(156.492188, 183.711807, 105.019775),
                vec3(153.899048, 180.666214, 105.019775)
            }
        },
        {
            coords = vec4(222.73846435547, 173.57801818848, 104.59851074219, 249.44882202148),
            locationLabel = "Vinewood Blvd",
            npcLocations = {
                vec3(222.132553, 171.672012, 104.598511),
                vec3(223.344376, 175.484024, 104.598511)
            }
        },
        {
            coords = vec4(239.49890136719, 115.09450531006, 101.98681640625, 153.07086181641),
            locationLabel = "Alta St",
            npcLocations = {
                vec3(238.204941, 116.619514, 101.986816),
                vec3(240.792862, 113.569496, 101.986816)
            }
        },
        {
            coords = vec4(265.68792724609, 69.745056152344, 93.73046875, 161.57479858398),
            locationLabel = "Alta St",
            npcLocations = {
                vec3(265.256897, 67.792053, 93.730469),
                vec3(266.118958, 71.698059, 93.730469)
            }
        },
        {
            coords = vec4(311.01098632812, 54.092308044434, 99.257202148438, 161.57479858398),
            locationLabel = "Power St",
            npcLocations = {
                vec3(310.579956, 52.139309, 99.257202),
                vec3(311.442017, 56.045307, 99.257202)
            }
        },
        {
            coords = vec4(272.8747253418, 67.31867980957, 99.257202148438, 155.90550231934),
            locationLabel = "Alta St",
            npcLocations = {
                vec3(273.647430, 65.473969, 99.257202),
                vec3(272.102020, 69.163391, 99.257202)
            }
        },
        {
            coords = vec4(285.62637329102, 8.7824182510376, 78.700317382812, 161.57479858398),
            locationLabel = "Power St",
            npcLocations = {
                vec3(285.195343, 6.829419, 78.700317),
                vec3(286.057404, 10.735417, 78.700317)
            }
        },
        {
            coords = vec4(549.57360839844, -145.04176330566, 57.604370117188, 175.74803161621),
            locationLabel = "Elgin Ave",
            npcLocations = {
                vec3(551.540894, -145.402100, 57.604370),
                vec3(547.606323, -144.681427, 57.604370)
            }
        },
        {
            coords = vec4(549.73187255859, -136.93186950684, 57.604370117188, 178.58267211914),
            locationLabel = "Elgin Ave",
            npcLocations = {
                vec3(547.965454, -135.993958, 57.604370),
                vec3(551.498291, -137.869781, 57.604370)
            }
        },
        {
            coords = vec4(914.74285888672, -144.72528076172, 75.296752929688, 235.27558898926),
            locationLabel = "Mirror Park Blvd",
            npcLocations = {
                vec3(912.859924, -144.051041, 75.296753),
                vec3(916.625793, -145.399521, 75.296753)
            }
        },
        {
            coords = vec4(942.38244628906, -246.14505004883, 67.967041015625, 328.81890869141),
            locationLabel = "Bridge St",
            npcLocations = {
                vec3(941.384399, -244.411880, 67.967041),
                vec3(943.380493, -247.878220, 67.967041)
            }
        },
        {
            coords = vec4(1122.3560791016, -402.80438232422, 67.545776367188, 260.78741455078),
            locationLabel = "West Mirror Drive",
            npcLocations = {
                vec3(1120.357300, -402.874817, 67.545776),
                vec3(1124.354858, -402.733948, 67.545776)
            }
        },
        {
            coords = vec4(1047.4681396484, -487.17361450195, 63.282836914062, 82.204727172852),
            locationLabel = "Bridge St",
            npcLocations = {
                vec3(1049.200439, -486.174103, 63.282837),
                vec3(1045.735840, -488.173126, 63.282837)
            }
        },
        {
            coords = vec4(1086.0131835938, -495.52087402344, 63.889404296875, 263.6220703125),
            locationLabel = "Bridge St",
            npcLocations = {
                vec3(1087.939819, -496.057648, 63.889404),
                vec3(1084.086548, -494.984100, 63.889404)
            }
        },
        {
            coords = vec4(1129.9516601562, -489.42855834961, 64.698120117188, 76.535430908203),
            locationLabel = "Mirror Park Blvd",
            npcLocations = {
                vec3(1130.791870, -487.613617, 64.698120),
                vec3(1129.111450, -491.243500, 64.698120)
            }
        },
        {
            coords = vec4(1144.2593994141, -475.50329589844, 65.709106445312, 76.535430908203),
            locationLabel = "Mirror Park Blvd",
            npcLocations = {
                vec3(1145.099609, -473.688354, 65.709106),
                vec3(1143.419189, -477.318237, 65.709106)
            }
        },
        {
            coords = vec4(1128.2769775391, -996.92309570312, 44.748046875, 93.543304443359),
            locationLabel = "El Rancho Blvd",
            npcLocations = {
                vec3(1129.800903, -998.218384, 44.748047),
                vec3(1126.753052, -995.627808, 44.748047)
            }
        },
        {
            coords = vec4(905.49890136719, -1139.4461669922, 23.83740234375, 175.74803161621),
            locationLabel = "Olympic Fwy",
            npcLocations = {
                vec3(907.466187, -1139.806519, 23.837402),
                vec3(903.531616, -1139.085815, 23.837402)
            }
        },
        {
            coords = vec4(706.35162353516, -1149.82421875, 23.264526367188, 357.16534423828),
            locationLabel = "Olympic Fwy",
            npcLocations = {
                vec3(707.471924, -1151.480957, 23.264526),
                vec3(705.231323, -1148.167480, 23.264526)
            }
        },
        {
            coords = vec4(453.75823974609, -1965.5867919922, 22.320922851562, 5.6692910194397),
            locationLabel = "Little Bighorn Ave",
            npcLocations = {
                vec3(455.393066, -1966.738892, 22.320923),
                vec3(452.123413, -1964.434692, 22.320923)
            }
        },
        {
            coords = vec4(405.03295898438, -2008.4044189453, 22.455688476562, 161.57479858398),
            locationLabel = "Carson Ave",
            npcLocations = {
                vec3(404.601929, -2010.357422, 22.455688),
                vec3(405.463989, -2006.451416, 22.455688)
            }
        },
        {
            coords = vec4(411.79779052734, -1931.0241699219, 23.618286132812, 34.015747070312),
            locationLabel = "Little Bighorn Ave",
            npcLocations = {
                vec3(410.084198, -1929.992920, 23.618286),
                vec3(413.511383, -1932.055420, 23.618286)
            }
        },
        {
            coords = vec4(206.08352661133, -2017.2263183594, 17.90625, 48.188972473145),
            locationLabel = "Dutch London St",
            npcLocations = {
                vec3(205.114670, -2018.975952, 17.906250),
                vec3(207.052383, -2015.476685, 17.906250)
            }
        },
        {
            coords = vec4(150.64614868164, -1965.6395263672, 18.293823242188, 45.354328155518),
            locationLabel = "Roy Lowenstein Blvd",
            npcLocations = {
                vec3(151.041061, -1963.678955, 18.293823),
                vec3(150.251236, -1967.600098, 18.293823)
            }
        },
        {
            coords = vec4(162.8571472168, -1927.3714599609, 20.450561523438, 48.188972473145),
            locationLabel = "Roy Lowenstein Blvd",
            npcLocations = {
                vec3(161.888290, -1929.121094, 20.450562),
                vec3(163.826004, -1925.621826, 20.450562)
            }
        },
        {
            coords = vec4(166.57582092285, -1857.7186279297, 23.567749023438, 340.15747070312),
            locationLabel = "Covenant Ave",
            npcLocations = {
                vec3(167.872391, -1856.195801, 23.567749),
                vec3(165.279251, -1859.241455, 23.567749)
            }
        },
        {
            coords = vec4(136.52307128906, -1893.9956054688, 22.725341796875, 153.07086181641),
            locationLabel = "Covenant Ave",
            npcLocations = {
                vec3(135.229111, -1892.470581, 22.725342),
                vec3(137.817032, -1895.520630, 22.725342)
            }
        },
        {
            coords = vec4(-10.720874786377, -1749.8901367188, 28.639526367188, 42.519683837891),
            locationLabel = "Davis Ave",
            npcLocations = {
                vec3(-10.504930, -1751.878418, 28.639526),
                vec3(-10.936819, -1747.901855, 28.639526)
            }
        },
        {
            coords = vec4(-25.832963943481, -1730.1494140625, 28.639526367188, 22.677164077759),
            locationLabel = "Davis Ave",
            npcLocations = {
                vec3(-27.380516, -1731.416382, 28.639526),
                vec3(-24.285412, -1728.882446, 28.639526)
            }
        },
        {
            coords = vec4(11.432968139648, -1713.5472412109, 28.656372070312, 28.34645652771),
            locationLabel = "Davis Ave",
            npcLocations = {
                vec3(9.438168, -1713.691406, 28.656372),
                vec3(13.427769, -1713.403076, 28.656372)
            }
        },
        {
            coords = vec4(31.608793258667, -1580.5582275391, 28.588989257812, 42.519683837891),
            locationLabel = "Strawberry Ave",
            npcLocations = {
                vec3(31.824738, -1582.546509, 28.588989),
                vec3(31.392849, -1578.569946, 28.588989)
            }
        },
        {
            coords = vec4(70.127471923828, -1556.4263916016, 28.80810546875, 235.27558898926),
            locationLabel = "Strawberry Ave",
            npcLocations = {
                vec3(68.244553, -1555.752197, 28.808105),
                vec3(72.010391, -1557.100586, 28.808105)
            }
        },
        {
            coords = vec4(148.36483764648, -1517.8681640625, 28.504760742188, 320.31497192383),
            locationLabel = "Davis Ave",
            npcLocations = {
                vec3(150.348602, -1518.122437, 28.504761),
                vec3(146.381073, -1517.613892, 28.504761)
            }
        },
        {
            coords = vec4(152.53187561035, -1498.8527832031, 28.487915039062, 320.31497192383),
            locationLabel = "Davis Ave",
            npcLocations = {
                vec3(154.515640, -1499.107056, 28.487915),
                vec3(150.548111, -1498.598511, 28.487915)
            }
        },
        {
            coords = vec4(166.72088623047, -1460.4527587891, 28.504760742188, 325.98425292969),
            locationLabel = "Davis Ave",
            npcLocations = {
                vec3(168.195953, -1461.803345, 28.504761),
                vec3(165.245819, -1459.102173, 28.504761)
            }
        },
        {
            coords = vec4(105.46813964844, -1400.3209228516, 28.622680664062, 323.14959716797),
            locationLabel = "Innocence Blvd",
            npcLocations = {
                vec3(103.653931, -1399.479126, 28.622681),
                vec3(107.282349, -1401.162720, 28.622681)
            }
        },
        {
            coords = vec4(44.808795928955, -1403.5120849609, 28.723754882812, 87.874015808105),
            locationLabel = "Innocence Blvd",
            npcLocations = {
                vec3(46.800598, -1403.692993, 28.723755),
                vec3(42.816994, -1403.331177, 28.723755)
            }
        },
        {
            coords = vec4(-17.789009094238, -1409.1296386719, 28.673217773438, 90.708656311035),
            locationLabel = "Innocence Blvd",
            npcLocations = {
                vec3(-19.633049, -1408.355347, 28.673218),
                vec3(-15.944969, -1409.903931, 28.673218)
            }
        },
        {
            coords = vec4(-114.19779968262, -1410.8835449219, 29.347290039062, 90.708656311035),
            locationLabel = "Innocence Blvd",
            npcLocations = {
                vec3(-116.041840, -1410.109253, 29.347290),
                vec3(-112.353760, -1411.657837, 29.347290)
            }
        },
        {
            coords = vec4(-83.472526550293, -1405.0549316406, 28.673217773438, 87.874015808105),
            locationLabel = "Innocence Blvd",
            npcLocations = {
                vec3(-81.480728, -1405.235840, 28.673218),
                vec3(-85.464325, -1404.874023, 28.673218)
            }
        },
        {
            coords = vec4(-138.81758117676, -1346.6768798828, 29.1787109375, 0.0),
            locationLabel = "Innocence Blvd",
            npcLocations = {
                vec3(-136.817581, -1346.676880, 29.178711),
                vec3(-140.817581, -1346.676880, 29.178711)
            }
        },
        {
            coords = vec4(-141.85055541992, -1415.2614746094, 29.8359375, 297.63778686523),
            locationLabel = "Innocence Blvd",
            npcLocations = {
                vec3(-143.224457, -1413.808105, 29.835938),
                vec3(-140.476654, -1416.714844, 29.835938)
            }
        },
        {
            coords = vec4(-333.41537475586, -1495.3846435547, 30.00439453125, 178.58267211914),
            locationLabel = "Alta St",
            npcLocations = {
                vec3(-335.181824, -1494.446777, 30.004395),
                vec3(-331.648926, -1496.322510, 30.004395)
            }
        },
        {
            coords = vec4(353.63076782227, 435.79779052734, 146.31872558594, 113.38582611084),
            locationLabel = "North Conker Ave",
            npcLocations = {
                vec3(355.548126, 436.366791, 146.318726),
                vec3(351.713409, 435.228790, 146.318726)
            }
        },
        {
            coords = vec4(319.81979370117, 494.69012451172, 151.96337890625, 102.04724884033),
            locationLabel = "North Conker Ave",
            npcLocations = {
                vec3(319.928772, 496.687164, 151.963379),
                vec3(319.710815, 492.693085, 151.963379)
            }
        },
        {
            coords = vec4(306.84396362305, 707.9736328125, 173.88500976562, 354.33071899414),
            locationLabel = "Baytree Canyon Rd",
            npcLocations = {
                vec3(305.275391, 709.214417, 173.885010),
                vec3(308.412537, 706.732849, 173.885010)
            }
        },
        {
            coords = vec4(52.773632049561, 563.65716552734, 179.71496582031, 243.77952575684),
            locationLabel = "Whispymound Dr",
            npcLocations = {
                vec3(53.376308, 561.750122, 179.714966),
                vec3(52.170956, 565.564209, 179.714966)
            }
        },
        {
            coords = vec4(-125.82856750488, 509.90768432617, 142.15673828125, 221.10237121582),
            locationLabel = "Wild Oats Dr",
            npcLocations = {
                vec3(-125.086891, 511.765076, 142.156738),
                vec3(-126.570244, 508.050293, 142.156738)
            }
        },
        {
            coords = vec4(-244.52307128906, 494.09671020508, 125.20581054688, 212.59841918945),
            locationLabel = "Wild Oats Dr",
            npcLocations = {
                vec3(-243.493225, 492.382233, 125.205811),
                vec3(-245.552917, 495.811188, 125.205811)
            }
        },
        {
            coords = vec4(-353.18240356445, 474.93627929688, 112.11352539062, 119.0551071167),
            locationLabel = "Didion Dr",
            npcLocations = {
                vec3(-351.287354, 474.296875, 112.113525),
                vec3(-355.077454, 475.575684, 112.113525)
            }
        },
        {
            coords = vec4(-315.52087402344, 479.18243408203, 112.18090820312, 138.89762878418),
            locationLabel = "Wild Oats Dr",
            npcLocations = {
                vec3(-313.950195, 480.420563, 112.180908),
                vec3(-317.091553, 477.944305, 112.180908)
            }
        },
        {
            coords = vec4(-318.21099853516, 432.96264648438, 108.94580078125, 195.5905456543),
            locationLabel = "Cox Way",
            npcLocations = {
                vec3(-316.834625, 434.413696, 108.945801),
                vec3(-319.587372, 431.511597, 108.945801)
            }
        },
        {
            coords = vec4(-349.95166015625, 426.65933227539, 110.00732421875, 240.94488525391),
            locationLabel = "Cox Way",
            npcLocations = {
                vec3(-351.102386, 428.295135, 110.007324),
                vec3(-348.800934, 425.023529, 110.007324)
            }
        },
        {
            coords = vec4(-361.84616088867, 436.87911987305, 109.46813964844, 294.80316162109),
            locationLabel = "Cox Way",
            npcLocations = {
                vec3(-360.097321, 435.908783, 109.468140),
                vec3(-363.595001, 437.849457, 109.468140)
            }
        },
        {
            coords = vec4(-392.38681030273, 436.12747192383, 111.69226074219, 56.69291305542),
            locationLabel = "Cox Way",
            npcLocations = {
                vec3(-390.407593, 436.414978, 111.692261),
                vec3(-394.366028, 435.839966, 111.692261)
            }
        },
        {
            coords = vec4(-447.75823974609, 374.16262817383, 104.12670898438, 277.79528808594),
            locationLabel = "Didion Dr",
            npcLocations = {
                vec3(-447.291260, 376.107361, 104.126709),
                vec3(-448.225220, 372.217896, 104.126709)
            }
        },
        {
            coords = vec4(-488.71649169922, 408.96264648438, 98.532592773438, 25.511812210083),
            locationLabel = "Cox Way",
            npcLocations = {
                vec3(-486.858459, 409.702759, 98.532593),
                vec3(-490.574524, 408.222534, 98.532593)
            }
        },
        {
            coords = vec4(-573.33624267578, 398.9010925293, 100.01538085938, 201.25984191895),
            locationLabel = "Milton Rd",
            npcLocations = {
                vec3(-571.375305, 399.294342, 100.015381),
                vec3(-575.297180, 398.507843, 100.015381)
            }
        },
        {
            coords = vec4(-602.33404541016, 396.55383300781, 101.1611328125, 181.41732788086),
            locationLabel = "Milton Rd",
            npcLocations = {
                vec3(-600.933533, 395.126038, 101.161133),
                vec3(-603.734558, 397.981628, 101.161133)
            }
        },
        {
            coords = vec4(-776.92749023438, 373.96484375, 87.226318359375, 0.0),
            locationLabel = "Picture Perfect Drive",
            npcLocations = {
                vec3(-774.927490, 373.964844, 87.226318),
                vec3(-778.927490, 373.964844, 87.226318)
            }
        },
        {
            coords = vec4(-796.31207275391, 373.45056152344, 87.2431640625, 0.0),
            locationLabel = "South Mo Milton Dr",
            npcLocations = {
                vec3(-794.312073, 373.450562, 87.243164),
                vec3(-798.312073, 373.450562, 87.243164)
            }
        },
        {
            coords = vec4(-947.90771484375, 308.79559326172, 70.528198242188, 2.8346455097198),
            locationLabel = "Dunstable Dr",
            npcLocations = {
                vec3(-949.814209, 309.399902, 70.528198),
                vec3(-946.001221, 308.191284, 70.528198)
            }
        },
    },
    ["container"] = {
        {
            container = vec4(898.5, -3085.4, 4.9, 270.1),
            vehicle =  vec4(901.5, -3085.4, 5.7, 89.7),
            locationLabel = "Los Santos Docks",
        },
        {
            container = vec4(819.3,-3087.9,4.9,270.3),
            vehicle = vector4(823.722, -3087.766, 5.463, 91.037),
            locationLabel = "West Side of Los Santos Docks",
        },
        {
            container = vector4(995.2,-2981.8,4.9,270.3),
            vehicle = vector4(999.362, -2981.789, 5.462, 89.858),
            locationLabel = "North Side of Los Santos Docks",
        },
        {
            container = vector4(1096.5,-2981.6,4.9,269.4),
            vehicle = vector4(1101.556, -2981.757, 5.475, 88.159),
            locationLabel = "North-East Side of Los Santos Docks",
        },
        {
            container = vector4(1174.8,-2968.1,4.9,89.8),
            vehicle = vector4(1170.816, -2968.086, 5.464, 269.651),
            locationLabel = "North-East Side of Los Santos Docks",
        },
        {
            container = vector4(1174.8,-2978.9,4.9,89.0),
            vehicle = vector4(1170.414, -2978.755, 5.464, 268.238),
            locationLabel = "North-East Side of Los Santos Docks",
        },
        {
            container = vector4(1217.1,-2984.6,4.9,0.4),
            vehicle = vector4(1217.098, -2980.183, 5.445, 179.528),
            locationLabel = "the cargo ship in the LS Docks",
        },
        {
            container = vector4(1059.7,-3039.6,4.9,90.7),
            vehicle = vector4(1055.417, -3039.746, 5.447, 271.744),
            locationLabel = "Los Santos Docks",
        },
        {
            container = vector4(987.3,-3024.7,4.9,180.7),
            vehicle = vector4(987.354, -3029.229, 5.447, 359.803),
            locationLabel = "Los Santos Docks",
        },
        {
            container = vector4(953.4,-3149.4,4.9,178.9),
            vehicle = vector4(953.294, -3153.232, 5.448, 359.112),
            locationLabel = "Los Santos Docks", 
        },
        {
            container = vector4(507.0,-2958.2,5.0,90.3),
            vehicle = vector4(501.981, -2958.278, 5.592, 269.702),
            locationLabel = "Elysian Island Docks",
        },
        {
            container = vector4(633.6,-2969.0,5.0,270.4),
            vehicle = vector4(637.676, -2968.942, 5.592, 89.508),
            locationLabel = "Elysian Island Docks",
        },
        {
            container = vector4(470.3,-2992.3,5.0,270.3),
            vehicle = vector4(475.103, -2992.187, 5.590, 89.931),
            locationLabel = "Elysian Island Docks",
        },
        {
            container = vector4(-61.5,-2233.1,6.8,88.6),
            vehicle = vector4(-65.919, -2232.974, 7.372, 269.003),
            locationLabel = "Banning Docks",
        }
    },
    ["trailer"] = {
        {
            coords = vec4(904.4, -3184.8, 6.0, 182.4),
            locationLabel = "Los Santos Docks",
        },
        {
            coords = vec4(-3166.787109, 1126.003662, 21.154625, 159.337875),
            locationLabel = "Chumash"
        },
        {
            coords = vec4(55.045219, 2801.230957, 58.066162, 231.773865),
            locationLabel = "Grand Senora Desert"
        },
        {
            coords = vec4(-1521.055908, -553.191406, 33.403999, 125.703560),
            locationLabel = "Del Perro"

        },
        {
            coords = vec4(-650.275940, -1766.486328, 24.682087, 298.306824),
            locationLabel = "La Puerta"
        },
    },
}

Config.PrestigeBoostsConfig = {
    ["5_more_payment"] = {
        priceBoost = 0.05,
    },
    ["add_vinscratch_chance"] = {
        vinScratchChance = 0.01,
    }
}

Config.PrestigeUnlocks = {
    [1] = {
        {
            weight = 95,
            name = "5_more_payment",
            label = locale("PRESTIGE_5_PAYMENT_LABEL"),
        },
        {
            weight = 5,
            name = "add_vinscratch_chance",
            label = locale("PRESTIGE_VIN_SCRATCH_LABEL"),
        }
    },
}

Config.ContractsCooldown = {
    ["E"] = 15,
    ["D"] = 0.5 * 60,
    ["C"] = 0.5 * 60,
    ["B"] = 0.75 * 60,
    ["A"] = 1.5 * 60,
    ["S"] = 2 * 60,
}

Config.ContractsGroupCooldown = {
    ["E"] = false,
    ["D"] = false,
    ["C"] = false,
    ["B"] = false,
    ["A"] = true,
    ["S"] = true,
}

Config.PolicePowerRequirement = {
    ["default"] = 0,
    ["E"] = 0,
    ["D"] = 0,
    ["C"] = 0,
    ["B"] = 0,
    ["A"] = 0,
    ["S"] = 0,
}

Config.BoostingGlovebox = {
    ["D"] = {
        {
            weight = 100,
            name = "moneyroll",
            count = {15, 20}
        },
    },
    ["C"] = {
        {
            weight = 100,
            name = "moneyroll",
            count = {20, 30}
        },
    },
    ["B"] = {
        {
            weight = 100,
            name = "moneyroll",
            count = {35, 60}
        },
    },
    ["A"] = {
        {
            weight = 100,
            name = "moneyband",
            count = {13, 20}
        },
    },
    ["S"] = {
        {
            weight = 100,
            name = "moneyband",
            count = {20, 35}
        },
    },
}

Config.Cases = {
    ["default"] = "BOOSTING_CASE",
    ["E"] = "BOOSTING_CASE",
    ["D"] = "BOOSTING_CASE",
    ["C"] = "BOOSTING_CASE_C",
    ["B"] = "BOOSTING_CASE_B",
    ["A"] = "BOOSTING_CASE_A",
    ["S"] = "BOOSTING_CASE_S",
}

Config.ContractTimeouts = {
    ["boosting"] = {
        ["D"] = -1,
        ["C"] = -1,
        ["B"] = -1,
        ["A"] = -1,
        ["S"] = 2 * 60 * 60,
    },
    ["vin_scratch"] = {
        ["D"] = -1,
        ["C"] = -1,
        ["B"] = -1,
        ["A"] = 2 * 24 * 60 * 60,
        ["S"] = 1 * 24 * 60 * 60,
    }
}

Config.CatchupRepModifier = {
    [10] = 3.5,
    [20] = 3.0,
    [30] = 2.0
}

Config.Items = {}
for k, v in pairs(Config.UnlockDrops) do
    Config.Items["boosting_contract_"..string.lower(k)] = {
        label = locale("BOOSTING_CONTRACT", k),
        rarity = "COMMON",
        weight = 1.0,
        isUsable = true,
        stackable = 10,
        server = {
            export = "prp-boosting.redeemContract"
        },
    }
end

for k, v in pairs(Config.VinScratchGeneration) do
    Config.Items["boosting_vinscratch_"..string.lower(k)] = {
        label = locale("VIN_SCRATCH_CONTRACT", k),
        rarity = "COMMON",
        weight = 1.0,
        isUsable = true,
        stackable = 10,
        server = {
            export = "prp-boosting.redeemVinScratch"
        },
    }
end