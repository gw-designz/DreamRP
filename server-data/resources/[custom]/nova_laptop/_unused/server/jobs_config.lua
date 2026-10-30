-- Server-only. Bosses advertise existing framework jobs; they cannot create
-- framework jobs, invent salaries, grant boss grades, or change webhook URLs.
Config.Jobs = {
    Enabled = true,
    DefaultHireGrades = { 0 }, -- explicit non-boss entry grades
    ESXBossGradeNames = { boss = true },
    ExcludedJobs = { unemployed = true },
    -- Optional job-specific rules. Omitted jobs use framework boss flags.
    Businesses = {
        -- mechanic = { label = 'Benny\'s Motor Works', hireGrades = { 0, 1 } },
        -- police = { enabled = false },
        -- taxi = { bossGrades = { 4 }, hireGrades = { 0 } }, -- custom boss grade
    },
    Categories = { 'Automotive', 'Hospitality', 'Retail', 'Transport', 'Public service', 'Professional', 'Other' },
    EmploymentTypes = { 'Full-time', 'Part-time', 'Contract' },
    MaxListingsPerBusiness = 12,
    MaxListings = 250,
    MaxApplications = 3000,
    MaxActiveApplications = 5,
    MaxApplicantsPerListing = 150,
    MaxOpenings = 50,
    MaxQuestions = 4,
    ListingLifetimeDays = 30,
    RetentionDays = 90, -- terminal applications and closed, unreferenced listings
    ReapplyCooldownSeconds = 3600,
    PollSeconds = 5,
    ReceiptLimit = 1200,
    Limits = { title = 80, location = 100, description = 2500, requirements = 1500,
        question = 180, answer = 600, cover = 1800, experience = 1200,
        availability = 240, contact = 80, message = 500, internalNote = 1200 },
    Webhook = {
        Enabled = false,
        DefaultConvar = 'nova_jobs_webhook',
        JobConvars = {
            -- mechanic = 'nova_jobs_webhook_mechanic'
        },
        Events = { application = true, decision = true },
        MaxQueue = 150,
        MaxAttempts = 5,
        -- Set only server convars in server.cfg, never replicated "setr":
        -- set nova_jobs_webhook "https://discord.com/api/webhooks/ID/TOKEN"
    }
}
