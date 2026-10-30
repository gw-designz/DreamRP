fx_version "cerulean"
game "gta5"
lua54 "yes"

author "Prodigy Studios"

files {
    "weaponarchetypes.meta",
    "weaponanimations.meta",
    "weapons.meta",
    'stream/**/*.ytyp'
}

data_file "WEAPON_METADATA_FILE" "weaponarchetypes.meta"
data_file "WEAPON_ANIMATIONS_FILE" "weaponanimations.meta"
data_file "WEAPONINFO_FILE" "weapons.meta"
data_file 'DLC_ITYP_REQUEST' 'stream/**/*.ytyp'
dependency '/assetpacks'