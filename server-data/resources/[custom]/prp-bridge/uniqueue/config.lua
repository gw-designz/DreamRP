-- TEMPORARY QUEUE CONFIG FILE
QueueConfig = {}

-- How much strength has a single police officer
QueueConfig.PoliceStrengthPerPlayer = 1
-- How much over time priority can player get (max)
QueueConfig.MaxOverTimePriority = 30

-- How often player gets over time priority (in seconds)
QueueConfig.AddOverTimePriorityTime = math.floor(2.5 * 60)
-- How long queue waits for player to reconnect (in seconds)
QueueConfig.DisconnectGraceTime = math.floor(10 * 60)

-- This is blocked any queue on resource start for the defined time.
QueueConfig.QueuesTotallyBlockedFor = 0

-- Jobs that are considered as police for police power calculation
QueueConfig.PoliceJobs = {
    "police",
    "bsco",
}