return {
	['testburger'] = {
		label = 'Test Burger',
		weight = 220,
		degrade = 60,
		client = {
			image = 'burger_chicken.png',
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			export = 'ox_inventory_examples.testburger'
		},
		server = {
			export = 'ox_inventory_examples.testburger',
			test = 'what an amazingly delicious burger, amirite?'
		},
		buttons = {
			{
				label = 'Lick it',
				action = function(slot)
					print('You licked the burger')
				end
			},
			{
				label = 'Squeeze it',
				action = function(slot)
					print('You squeezed the burger :(')
				end
			},
			{
				label = 'What do you call a vegan burger?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('A misteak.')
				end
			},
			{
				label = 'What do frogs like to eat with their hamburgers?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('French flies.')
				end
			},
			{
				label = 'Why were the burger and fries running?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('Because they\'re fast food.')
				end
			}
		},
		consume = 0.3
	},

    ['pd_watch'] = {
    label = 'PD Watch',
    weight = 100,
    stack = false,
    close = true,
    client = {
        export = 'pd_watch.useWatch',
    },
},

	['whiteboard'] = { label = 'Whiteboard', weight = 9000, stack = false, close = true, consume = 0, description = 'Use it to put it up.', client = { export = 'fs-whiteboard.useItem' } },

	['bandage'] = {
		label = 'Bandage',
		weight = 115,
		client = {
			anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },
			prop = { model = `prop_rolled_sock_02`, pos = vec3(-0.14, -0.14, -0.08), rot = vec3(-50.0, -50.0, 0.0) },
			disable = { move = true, car = true, combat = true },
			usetime = 2500,
		}
	},

	['black_money'] = {
		label = 'Dirty Money',
	},

	['handcuffs'] = {
    label = 'Handcuffs',
    weight = 250,
    stack = false,
    close = false,
},

['cuffs_key'] = {
    label = 'Handcuff Key',
    weight = 50,
    stack = false,
    close = true,
},

['battering_ram'] = {
    label = 'Battering Ram',
    weight = 8000,
    stack = false,
    close = true,
},

['cable_ties'] = {
    label = 'Cable Ties',
    weight = 100,
    stack = false,
    close = false,
},

['mouthtape'] = {
    label = 'Duct Tape',
    weight = 100,
    stack = false,
    close = false,
},

['headbag'] = {
    label = 'Head Bag',
    weight = 200,
    stack = false,
    close = true,
},

['body_cam'] = {
    label = 'Body Camera',
    weight = 500,
    stack = false,
    close = true,
},

['breathalyzer'] = {
    label = 'Breathalyzer',
    weight = 200,
    stack = false,
    close = true,
},

['drug_test_kit'] = {
    label = 'Drug Test Kit',
    weight = 200,
    stack = false,
    close = true,
},

['camera'] = {
    label = 'Camera',
    weight = 1000,
    stack = false,
    close = true,
},

['photo'] = {
    label = 'Photo',
    weight = 50,
    stack = false,
    close = true,
},

['gps'] = {
    label = 'GPS',
    weight = 100,
    stack = false,
    close = false,
},

['megaphone'] = {
    label = 'Megaphone',
    weight = 800,
    stack = false,
    close = false,
},

['fingerprint_scanner'] = {
    label = 'Fingerprint Scanner',
    weight = 200,
    stack = false,
    close = true,
},

['nightvision'] = {
    label = 'Night Vision Goggles',
    weight = 500,
    stack = false,
    close = false,
},

['thermalvision'] = {
    label = 'Thermal Goggles',
    weight = 500,
    stack = false,
    close = false,
},

['rappel_kit'] = {
    label = 'Rappel Kit',
    weight = 1000,
    stack = false,
    close = true,
},

['police_shield'] = {
    label = 'Police Shield',
    weight = 2500,
    stack = false,
    close = false,
},

['tracking_band'] = {
    label = 'Tracking Band',
    weight = 250,
    stack = false,
    close = true,
},

['tracking_vehicle'] = {
    label = 'Vehicle Tracker',
    weight = 500,
    stack = false,
    close = true,
},

['wheel_clamp'] = {
    label = 'Wheel Clamp',
    weight = 5000,
    stack = false,
    close = true,
},

['roadcone'] = {
    label = 'Road Cone',
    weight = 800,
    stack = true,
    close = true,
},

['barrier'] = {
    label = 'Barrier',
    weight = 2000,
    stack = true,
    close = true,
},

['consign'] = {
    label = 'Road Sign',
    weight = 1500,
    stack = true,
    close = true,
},

['spikestrip'] = {
    label = 'Spike Strip',
    weight = 3000,
    stack = true,
    close = true,

},

['police_diving_suit'] = {
    label = 'Police Diving Suit',
    weight = 2000,
    stack = false,
    close = true,

},

['diving_suit'] = {
    label = 'Diving Suit',
    weight = 2000,
    stack = false,
    close = true,

},

['player_clothes'] = {
    label = 'Civilian Clothes',
    weight = 100,
    stack = false,
    close = true,

},

['vest_normal'] = {
    label = 'Bulletproof Vest',
    weight = 3000,
    stack = false,
    close = true,

},

['vest_strong'] = {
    label = 'Heavy Bulletproof Vest',
    weight = 5000,
    stack = false,
    close = true,

},

['evidence_kit'] = {
    label = 'Evidence Kit',
    weight = 300,
    stack = true,
    close = true,

},

['swab_kit'] = {
    label = 'Swab Kit',
    weight = 100,
    stack = true,
    close = true,

},

['fingerprint_kit'] = {
    label = 'Fingerprint Kit',
    weight = 200,
    stack = true,
    close = true,

},

['cleaning_kit'] = {
    label = 'Cleaning Kit',
    weight = 500,
    stack = true,
    close = true,

},

['broom'] = {
    label = 'Broom',
    weight = 1000,
    stack = true,
    close = true,

},

['evidence_reconstructor'] = {
    label = 'Evidence Reconstructor',
    weight = 500,
    stack = false,
    close = true,

},

['evidence_blood'] = {
    label = 'Blood Sample',
    weight = 50,
    stack = false,
    close = true,

},

['evidence_casing'] = {
    label = 'Bullet Casing',
    weight = 30,
    stack = false,
    close = true,

},

['evidence_fingerprint'] = {
    label = 'Fingerprint',
    weight = 10,
    stack = false,
    close = true,

},

['evidence_drug_residue'] = {
    label = 'Drug Residue',
    weight = 50,
    stack = false,
    close = true,

},

['evidence_fragment'] = {
    label = 'Weapon Fragment',
    weight = 100,
    stack = false,
    close = true,

},

	['burger'] = {
		label = 'Burger',
		weight = 220,
		client = {
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			notification = 'You ate a delicious burger'
		},
	},

	['blue_keycard'] = {
    label = 'Blue Keycard',
    weight = 100,
    stack = false
},

['purple_keycard'] = {
    label = 'Purple Keycard',
    weight = 100,
    stack = false
},

['hack_usb'] = {
    label = 'Phantom USB',
    weight = 100,
    stack = false
},

['hack_card'] = {
    label = 'Spoofing Card',
    weight = 100,
    stack = false
},

['coins'] = {
    label = 'Coins',
    weight = 10,
},

['painting'] = {
    label = 'Painting',
    weight = 100,
},

['bomb_c4'] = {
    label = 'C4 Explosive',
    weight = 3000,
},

['angle_grinder'] = {
    label = 'Angle Grinder',
    weight = 1500,
},

['contracts_tablet'] = {
    label = 'Contract Tablet',
    stack = false,
    weight = 400,
},

['classified_docs'] = {
    label = 'Classified Documents',
    weight = 100,
},

['diamond_necklace'] = {
    label = 'Diamond Necklace',
    weight = 100,
},

['diamonds_box'] = {
    label = 'Diamonds Box',
    weight = 200,
},

['luxurious_watch'] = {
    label = 'Luxurious Watch',
    weight = 200,
},

['rare_coins'] = {
    label = 'Rare Coins',
    weight = 500,
},

['diamond_ring'] = {
    label = 'Diamond Ring',
    weight = 50,
},

['thermite'] = {
    label = 'Thermite',
    weight = 350,
},

['gold_bar'] = {
    label = 'Gold Bar',
    weight = 500,
},

["large_drill"] = {
    label = "Large Drill",
    weight = 12500,
    stack = true,
    close = true,
},

['casino_keycard'] = {
    label = 'Casino Keycard',
    weight = 100,
    stack = false
},

["small_drill"] = {
    label = "Small Drill",
    weight = 2000,
    stack = true,
    close = true,
},

['explosives'] = {
    label = 'Explosives',
    weight = 3000,
},

['tv'] = {
    label = 'Television',
    weight = 12500,
    stack = true,
},

['microwave'] = {
    label = 'Microwave',
    weight = 7500,
    stack = true,
},

['monitor'] = {
    label = 'Computer Monitor',
    weight = 5000,
    stack = true,
},

['printer'] = {
    label = 'Printer',
    weight = 10000,
    stack = true,
},

['flat_tv'] = {
    label = 'Flat Screen TV',
    weight = 12500,
    stack = true,
},

['old_tv'] = {
    label = 'Old TV',
    weight = 12500,
    stack = true,
},

['dj_deck'] = {
    label = 'DJ Deck',
    weight = 7500,
    stack = true,
},

['console'] = {
    label = 'Gaming Console',
    weight = 3000,
    stack = true,
},

['keyboard'] = {
    label = 'Keyboard',
    weight = 500,
    stack = true,
},

['laptop'] = {
    label = 'Laptop',
    weight = 2500,
    stack = true,
},

['bong'] = {
    label = 'Bong',
    weight = 1000,
    stack = true,
},

['meth_bag'] = {
    label = 'Meth Bag',
    weight = 50,
    stack = true,
},

['coke_brick'] = {
    label = 'Coke Brick',
    weight = 200,
    stack = true,
},

['weed_brick'] = {
    label = 'Weed Brick',
    weight = 200,
    stack = true,
},

['pink_diamond'] = {
    label = 'Pink Diamond',
    weight = 100,
},

['rare_tequila'] = {
    label = 'Rare Tequila',
    weight = 300,
},

['plasma_cutter'] = {
    label = 'Plasma cutter',
    weight = 1000,
    stack = true,
},

	['sprunk'] = {
		label = 'Sprunk',
		weight = 350,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
			usetime = 2500,
			notification = 'You quenched your thirst with a sprunk'
		}
	},

	['parachute'] = {
		label = 'Parachute',
		weight = 8000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 1500
		}
	},

	['garbage'] = {
		label = 'Garbage',
	},

	['paperbag'] = {
		label = 'Paper Bag',
		weight = 1,
		stack = false,
		close = false,
		consume = 0
	},

	['thermite'] = {
		label = 'Thermite',
		weight = 1,
		stack = true,
		close = false,
		consume = 0
	},

	['identification'] = {
		label = 'Identification',
		client = {
			image = 'card_id.png'
		}
	},

	['panties'] = {
		label = 'Knickers',
		weight = 10,
		consume = 0,
		client = {
			status = { thirst = -100000, stress = -25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
			usetime = 2500,
		}
	},

	-- The three lockpick tiers all play lockpick_minigame (difficulty per tier in its
	-- config.lua). Using one from the inventory hands off to that resource, which picks
	-- a building door (sophisticated only) or a vehicle. There used to be a second
	-- 'lockpick' entry further up (p_policejob's items); this is the only one now.
	['lockpick'] = {
		label = 'Regular Lockpick',
		weight = 160,
		description = 'Gets you into cars and out of cuffs. Hardest to work.',
		client = { export = 'lockpick_minigame.useItem' },
	},

	['advancedlockpick'] = {
		label = 'Advanced Lockpick',
		weight = 160,
		description = 'A better set of picks for cars and cuffs.',
		client = { export = 'lockpick_minigame.useItem' },
	},

	['sophisticated_lockpick'] = {
		label = 'Sophisticated Lockpick',
		weight = 200,
		description = 'Professional picks. Opens building doors as well as everything else.',
		client = { image = 'advancedlockpick.png', export = 'lockpick_minigame.useItem' },
	},

	['phone'] = {
		label = 'Phone',
		weight = 190,
		stack = false,
		consume = 0,
		client = {
			add = function(total)
				if total > 0 then
					pcall(function() return exports.npwd:setPhoneDisabled(false) end)
				end
			end,

			remove = function(total)
				if total < 1 then
					pcall(function() return exports.npwd:setPhoneDisabled(true) end)
				end
			end
		}
	},

	['money'] = {
		label = 'Money',
	},

	['mustard'] = {
		label = 'Mustard',
		weight = 500,
		client = {
			status = { hunger = 25000, thirst = 25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
			usetime = 2500,
			notification = 'You.. drank mustard'
		}
	},

	['water'] = {
		label = 'Water',
		weight = 500,
		client = {
			status = { thirst = 200000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
			usetime = 2500,
			cancel = true,
			notification = 'You drank some refreshing water'
		}
	},

	['radio'] = {
		label = 'Radio',
		weight = 1000,
		stack = false,
		allowArmed = true
	},

	['armour'] = {
		label = 'Bulletproof Vest',
		weight = 3000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 3500
		}
	},

	['clothing'] = {
		label = 'Clothing',
		consume = 0,
	},

	['mastercard'] = {
		label = 'Fleeca Card',
		stack = false,
		weight = 10,
		client = {
			image = 'card_bank.png'
		}
	},

	['scrapmetal'] = {
		label = 'Scrap Metal',
		weight = 80,
	},

['laptop'] = {
    label = 'Weazel Laptop',
    weight = 2000,
    stack = false,
    close = true,
    consume = 0,
    description = 'LifeInvader for Business, Weazel Writer and the magazine desk.',
    client = {
        image = 'laptop.png',
        export = 'nova_laptop.UseLaptop'
    }
},

-- Used up by the office printer, one sheet per copy (Config.News.Printing.Paper).
['paper'] = {
    label = 'Paper',
    weight = 5,
    description = 'A sheet of printer paper.',
},

-- A printed issue. Its metadata says which issue; using it opens the reader.
['magazine'] = {
    label = 'LifeInvader Magazine',
    weight = 150,
    stack = false,
    close = true,
    consume = 0, -- reading it keeps it
    description = 'A printed copy of LifeInvader Magazine.',
    client = {
        export = 'nova_laptop.ReadMagazine'
    }
},

}
