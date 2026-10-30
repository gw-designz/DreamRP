Locales = Locales or {}

Locales['en'] = {
    -- generic
    ['no_permission'] = 'You do not have permission to do that.',
    ['qbx_core_missing'] = '^1[qb-doorcreator] qbx_core was not found or failed to start. This resource requires the Qbox framework (qbx_core). Stopping qb-doorcreator.^0',

    -- door interaction (client-facing, player)
    ['door_locked'] = 'Door locked.',
    ['door_unlocked'] = 'Door unlocked.',
    -- Deliberately generic: denial messages never reveal WHICH access
    -- category (job/item/gang/etc.) was missing, so players can't use
    -- a locked door's error message to fingerprint what a restricted
    -- area requires.
    ['access_denied'] = 'You do not have access to this door.',
    ['access_denied_password'] = 'Incorrect password.',
    ['access_denied_dependency'] = 'This door is locked until its dependencies are satisfied.',
    ['prompt_lock'] = 'Lock',
    ['prompt_unlock'] = 'Unlock',
    ['password_prompt_title'] = 'Enter Door Code',
    ['password_prompt_label'] = 'Access code',
    ['auto_relock_notice'] = 'This door will automatically re-lock in %{seconds}s.',

    -- creator / admin workflow
    ['creator_start'] = 'Door placement mode started. Aim at a door and press %{key} to select. Hold %{mod} to multi-select. %{cancel} to cancel.',
    ['creator_start_link'] = 'Aim at the other door and press %{key} to link it. %{cancel} to cancel.',
    ['creator_cancelled'] = 'Door placement cancelled.',
    ['creator_no_entity'] = 'No valid entity under crosshair.',
    ['creator_selected'] = 'Selected %{model} — press %{key} again to confirm, or select another to multi-select.',
    ['creator_confirmed_multi'] = '%{count} entities captured. Link as a door group?',
    ['creator_link_group_yes'] = 'Yes, link as group',
    ['creator_link_group_no'] = 'No, create separately',
    ['creator_max_group'] = 'You can only link up to %{max} doors in one group at a time.',

    -- NUI / management
    ['door_created'] = 'Door "%{label}" created.',
    ['door_updated'] = 'Door "%{label}" updated.',
    ['door_deleted'] = 'Door "%{label}" deleted.',
    ['generic_error'] = 'Something went wrong. Check server console.',
    ['invalid_input'] = 'Invalid input — please check the form and try again.',
    -- The delete-confirmation modal itself lives in web/app.js (it is
    -- plain NUI HTML, not an ox_lib/Lua dialog), so its copy is not
    -- routed through this locale table - see renderDeleteModal().
    ['located_door'] = 'Waypoint set to %{label}.',
    ['teleported_door'] = 'Teleported near %{label}.',

    -- context menu
    ['menu_title'] = 'Door Creator',
    ['menu_create'] = 'Place New Door',
    ['menu_manage'] = 'Manage Doors',
}

-- Simple %{key} substitution + oxLib default-locale fallback.
-- Kept here (not in shared/doorgroups.lua) so translators only ever
-- need to touch files under locales/.
Lang = Lang or {}

function Lang.T(key, subs)
    local template = (Locales[GetConvar('qb_locale', 'en')] or Locales['en'])[key]
    if not template then return key end
    if not subs then return template end
    return (template:gsub('%%{(%w+)}', function(k) return tostring(subs[k] or '') end))
end
