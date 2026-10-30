-- ============================================================
-- mock.lua  –  bablo-billing  (server, DEBUG only)
-- ============================================================

local m = {}

m.mockInvoices = {
    {
        id                   = "INVOICE-12345",
        sender               = "Jane Smith",
        amount               = 250.00,
        date                 = "2023-10-02",
        status               = "paid",
        created_at           = os.time() * 1000,
        paid_at              = "2023-10-02 14:00:00",
        title                = "Sasdasdt",
        description          = "Payment for services rendered",
        issuer_identifier    = "john_doe",
        recipient_identifier = "jane_smith",
    },
    {
        id                   = "INVOICE-12346",
        sender               = "Jane Smith",
        amount               = 250.00,
        date                 = "2023-10-02",
        status               = "paid",
        created_at           = os.time() * 1000,
        paid_at              = "2023-10-02 14:00:00",
        title                = "Service Payment",
        description          = "Payment for services rendered",
        issuer_identifier    = "john_doe",
        recipient_identifier = "jane_smith",
    },
    {
        id                   = "INVOICE-12347",
        sender               = "Jane Smith",
        amount               = 250.00,
        date                 = "2023-10-02",
        status               = "paid",
        created_at           = os.time() * 1000,
        paid_at              = "2023-10-02 14:00:00",
        title                = "Service Payment",
        description          = "Payment for services rendered",
        issuer_identifier    = "john_doe",
        recipient_identifier = "jane_smith",
    },
    {
        id                   = "INVOICE-12348",
        sender               = "Jane Smith",
        amount               = 250.00,
        date                 = "2023-10-02",
        status               = "paid",
        created_at           = os.time() * 1000,
        paid_at              = "2023-10-02 14:00:00",
        title                = "Service Payment",
        description          = "Payment for services rendered",
        issuer_identifier    = "john_doe",
        recipient_identifier = "jane_smith",
    },
    {
        id                   = "INVOICE-12350",
        sender               = "Jane Smith",
        amount               = 250.00,
        date                 = "2023-10-02",
        status               = "pending",
        created_at           = os.time() * 1000,
        paid_at              = false,
        title                = "Service Payment",
        description          = "Payment for services rendered",
        issuer_identifier    = "john_doe",
        recipient_identifier = "jane_smith",
    },
}

MockData = m
