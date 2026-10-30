Config = Config or {}

Config.Lookup = Config.Lookup or {}

--- ACE permission checked by Lookup server callbacks (`IsPlayerAceAllowed`). Grant in `server.cfg`, e.g.
--- `add_ace group.admin yseries.lookup allow` (use the same string as below if you change it).
---@type string
Config.Lookup.AcePermission = 'yseries.lookup'

--- Default field order for QB / QBX (`players` row shape).
---@type string[]
Config.Lookup.DefaultQbFieldOrder = {
    'citizenid',
    'rowId',
    'userId',
    'cid',
    'license',
    'usersUsername',
    'usersLicense',
    'license2',
    'fivem',
    'discord',
    'steamName',
    'phone',
    'cash',
    'bank',
    'crypto',
    'jobLabel',
    'jobName',
    'jobType',
    'jobGrade',
    'jobLevel',
    'jobPayment',
    'jobOnDuty',
    'jobIsBoss',
    'gangLabel',
    'gangName',
    'gangGrade',
    'gangLevel',
    'gangIsBoss',
    'firstName',
    'lastName',
    'dob',
    'gender',
    'nationality',
    'position',
    'fingerprint',
    'bloodtype',
    'lastUpdated',
    'lastLoggedOut',
    'inventory',
}

--- Default field order for ESX (`users` row shape).
---@type string[]
Config.Lookup.DefaultEsxFieldOrder = {
    'identifier',
    'firstname',
    'lastname',
    'phone',
    'phoneNumber',
    'dob',
    'sex',
    'height',
    'group',
    'jobLabel',
    'jobId',
    'jobGradeLabel',
    'jobGradeNum',
    'cash',
    'bank',
    'blackMoney',
    'position',
    'status',
    'createdAt',
    'lastSeen',
    'inventory',
}
