GPS = {}

GPS.ProgressBar = {
    name = "placing_gps",
    label = locale("PLACING_GPS"),
    duration = 10000,
    disable = {disableMovement = true, disableCarMovement = true},
    useWhileDead = false,
    canCancel = true,
    ignoreModifier = true,
    controlDisables = {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    },
    animation = {
        animDict = 'amb@world_human_vehicle_mechanic@male@base',
        animClip = 'base',
        animFlag = 1,
    },
}

GPS.RemoveDeviceProgressBar = {
    name = "policeutils_cps_remove",
    label = locale("REMOVING_DEVICE"),
    duration = 5000,
    disable = {disableMovement = true, disableCarMovement = true},
    useWhileDead = false,
    canCancel = true,
    ignoreModifier = true,
    controlDisables = {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    },
    animation = {
        animDict = 'mini@repair',
        animClip = 'fixing_a_ped',
        animFlag = 49,
    },
}

GPS.attach = {
    modelHash = `prp_shootable_gps`,
    offset = vector3(0.0, 0.0, 0.08),
    rot = vector3(0.0, 0.0, 0.0),
    boneId = "neon_f",
}

GPS.Items = {
    shootable_gps = 'shootable_gps',
    placeable_gps = 'placeable_gps',
}