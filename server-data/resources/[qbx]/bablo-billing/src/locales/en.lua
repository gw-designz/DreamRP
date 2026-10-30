
Locales['en'] = {
    accountTypes = {
        business = "Business Account",
        personal = "Personal Account",
        requires_job = "Requires a job",
        cannot_switch = "Cannot Switch Account",
        need_job_message = "You need to have a job to use business account"
    },
    pagination = {
        showing = "Showing {start} to {end} of {total} results",
        items_per_page = "Items per page",
        go_to_first = "Go to first page",
        go_to_previous = "Go to previous page",
        go_to_next = "Go to next page",
        go_to_last = "Go to last page",
        page = "Page {page}",
        of_pages = "of {total} pages"
    },
    sidebar = {
        navigation = {
            title = "Navigation"
        },
        header = {
            title = "City Billing",
            subtitle = "Billing made easy"
        },
        routes = {
            dashboard = "Dashboard",
            sent = "Sent Invoices",
            received = "Received Invoices",
            contacts = "Contacts"
        },
        user_menu = {
            settings = "Settings",
            templates = "Templates",
            profile = "Profile",
            personal_account = "Personal Account",
            job_account = "Job Account",
            account_management = "Account Management"
        }
    },
    settings = {
        title = "Settings",
        subtitle = "Customize your preferences",
        theme = {
            title = "Theme",
            light = "Light",
            dark = "Dark",
            system = "System"
        },
        templates = {
            title = "Template Management",
            subtitle = "Manage your invoice templates and presets",
            manage_button = "Manage Templates",
            dialog_title = "Template Management",
            custom_title = "Custom Templates",
            custom_count = "You have {count} custom templates",
            default_title = "Default Templates",
            default_count = "{count} built-in templates available"
        }
    },
    userMenu = {
        settings = "Settings",
        templates = "Templates",
        profile = "Profile",
        templateDialog = {
            title = "Template Management"
        }
    },
    dashboard = {
        header = {
            title = "Dashboard",
            subtitle = "Overview of your billing activities"
        },
        stats = {
            unpaid = "Amount of Unpaid Invoices",
            total = "Total Invoice Cost"
        },
        latest = {
            title = "Latest received invoices",
            subtitle = "Recent invoices you have received",
            empty = "No invoices received yet"
        }
    },
    paid = "Paid",
    pay = "Pay",
    ["invoice-card"] = {
        amount = "Amount to pay",
        actions = {
            details = "View Details",
            pay = "Pay Invoice"
        }
    },
    sent_invoices = {
        header = {
            title = "Sent Invoices",
            subtitle =
            "Here you can see all invoices you have sent to your customers. You can also manage them, check payment status, and more."
        },
        create_button = "Create New Invoice",
        loading = "Loading sent invoices...",
        empty = "No sent invoices found.",
        tabs = {
            card = "Card View",
            table = "Table View"
        },
        table = {
            title = "Invoices",
            search_placeholder = "Search by invoice number, title, or customer...",
            per_page = "page",
            filter = {
                all = "All Statuses",
                pending = "Pending",
                paid = "Paid",
                cancelled = "Cancelled"
            },
            sort = {
                status = "Status",
                date = "Date",
                amount = "Amount",
                title = "Title"
            },
            sort_select = {
                title = "Sort by",
                options = {
                    date_desc = "Date",
                    amount_desc = "Amount",
                    title_desc = "Title",
                    status_desc = "Status"
                }
            },
            columns = {
                invoice_number = "Invoice #",
                title = "Title",
                receiver = "Receiver",
                date = "Date",
                amount = "Amount",
                status = "Status",
                actions = "Actions"
            }
        },
        delete = {
            title = "Delete Invoice",
            description =
            "Are you sure you want to delete the invoice \"{title}\" (#{id})? This action cannot be undone.",
            success_title = "Invoice Deleted",
            success_description = "The invoice has been successfully deleted.",
            error_title = "Delete Failed",
            error_description = "Failed to delete the invoice. Please try again."
        },
        statuses = {
            all = "All Statuses",
            paid = "Paid",
            unpaid = "Unpaid",
            pending = "Pending"
        }
    },
    received_invoices = {
        loading = "Loading received invoices...",
        pay_dialog = {
            title = "Are you sure you want to pay this invoice?",
            description = "You are about to pay the invoice with id {invoiceId} for {amount}.",
            confirm = "Pay Invoice",
            cancel = "Cancel"
        },
        header = {
            title = "Received Invoices",
            subtitle = "Manage received invoices with card or table view"
        },
        tabs = {
            card = "Card View",
            table = "Table View"
        },
        error = {
            tittle = "No invoices found",
            subtitle = "There are no received invoices to display."
        },
        end_of_list = "All invoices loaded",
        table = {
            title = "Invoices",
            search_placeholder = "Search by invoice number or sender",
            sort_select = {
                title = "Sort by",
                options = {
                    date_desc = "Date",
                    amount_desc = "Amount",
                    title_desc = "Title",
                    status_desc = "Status"
                }
            },
            columns = {
                invoice_number = "Invoice #",
                title = "Title",
                receiver = "Receiver",
                date = "Date",
                amount = "Amount",
                status = "Status",
                actions = "Actions",
                action = "Pay"
            }
        }
    },
    statuses = {
        all = "All Statuses",
        paid = "Paid",
        unpaid = "Unpaid",
        pending = "Pending",
        cancelled = "Cancelled"
    },
    invoice_details = {
        types = {
            sent = "Sent Invoice",
            received = "Received Invoice"
        },
        descriptions = {
            sent = "Details for sent invoice",
            received = "Invoice details and information"
        },
        labels = {
            you = "You",
            item = "item",
            items = "items"
        },
        line_items = {
            title = "Invoice Items",
            description = "Description",
            qty = "Qty",
            quantity = "Quantity",
            unit_price = "Unit Price",
            total = "Total",
            footer = {
                based_on = "Based on",
                single_amount = "Single amount invoice"
            }
        },
        cards = {
            info = {
                title = "Invoice Information",
                invoice_number = "Invoice #",
                status = "Status"
            },
            amount = {
                title = "Amount",
                total = "Total Amount"
            },
            involved = {
                title = "Involved Parties",
                sender = "Sender",
                receiver = "Receiver"
            },
            description = {
                title = "Description",
                details = "Details"
            },
            line_items = {
                title = "Invoice Items",
                quantity = "Quantity",
                unit_price = "Unit Price",
                total = "Total"
            },
            date = {
                title = "Date",
                created = "Created",
                due = "Due Date"
            }
        }
    },
    create_invoice = {
        success = {
            title = "Invoice created",
            business = "The invoice has been sent via the company's system.",
            personal = "Your personal invoice has been successfully created."
        },
        error = {
            title = "Error",
            description = "Could not create the invoice."
        },
        players = {
            none_found = {
                title = "No players found",
                description = "There are no online players nearby."
            },
            closest_selected = {
                title = "Closest player selected",
                description = "{identifier} ({distance}m away) has been selected as the recipient."
            },
            fetch_error = {
                title = "Error",
                description = "Could not fetch nearby players."
            }
        },
        form = {
            identifier = {
                label = "Identifier",
                description = "Closest player"
            },
            details = {
                label = "Details",
                description = "Enter the details of the invoice."
            },
            title = {
                label = "Title",
                placeholder = "Invoice for services rendered",
                description = "A short description of what the invoice is about."
            },
            description = {
                label = "Description",
                placeholder = "Detailed description of services or products...",
                description = "Describe in detail what is being invoiced."
            },
            amount = {
                label = "Amount",
                description = "Invoice amount."
            },
            due_date = {
                label = "Due date",
                description = "When the invoice should be paid at the latest."
            },
            multiple_items = {
                toggle_label = "Multiple services/products",
                toggle_description = "Enable to add multiple items to the same invoice (e.g. car repairs, tuning, etc.)",
                amount_auto_calculated = "Automatically calculated from the lines below",
                services_products_title = "Services & Products",
                services_products_description = "Add all services and products to be invoiced",
                add_line = "Add line",
                line_number = "Line {number}",
                description_label = "Description *",
                description_placeholder = "Description of service or product (e.g. 'Engine tuning', 'Tire change', etc.)",
                quantity_label = "Quantity *",
                unit_price_label = "Unit price *",
                line_total = "Line total:",
                total_to_pay = "Total to pay:",
                details_label = "Details:"
            },
            footer = {
                business = "The invoice is automatically sent via the company's system.",
                personal = "The invoice is saved for manual handling."
            },
            actions = {
                cancel = "Cancel",
                creating = "Creating...",
                sending = "Sending...",
                send_invoice = "Send invoice",
                create_send = "Create & Send",
                create_invoice = "Create invoice"
            }
        },
        dialog = {
            business = {
                title = "Business Invoice",
                description = "Create and send invoices via your company's system.",
                badge = "Business"
            },
            personal = {
                title = "Create New Invoice",
                description = "Send a professional invoice to another player",
                badge = "Personal"
            }
        }
    },
    notifications = {
        invoice_received = {
            title = "New Invoice Received",
            message = "You have received a new invoice for ${amount} from {sender}",
            simple = "New invoice received for ${amount}"
        },
        job_invoice_paid = {
            title = "Job Invoice Paid",
            message = "A job invoice of ${amount} has been paid for {job}",
            simple = "Job invoice paid: ${amount}"
        }
    },
    common = {
        descriptions = {
            invoice_paid = "Invoice Paid",
            invoice_payment = "Invoice Payment"
        },
        ready = "Ready!",
        loading = {
            welcome = "Welcome {name}",
            initializing = "Initializing system...",
            loading_data = "Loading your data...",
            almost_ready = "Almost ready..."
        },
        ui = {
            loading = "Loading...",
            error = "Error",
            view_all = "View All",
            not_available = "N/A"
        },
        actions = {
            view = "View",
            cancel = "Cancel",
            creating = "Creating...",
            save = "Save",
            edit = "Edit",
            delete = "Delete",
            deleting = "Deleting...",
            confirm = "Confirm",
            close = "Close"
        },
        labels = {
            invoice_number = "Invoice #",
            title = "Title",
            customer = "Customer",
            date = "Date",
            amount = "Amount",
            actions = "Actions",
            status = "Status",
            description = "Description",
            from = "From (Issuer)",
            user_avatar = "User Avatar",
            business_account = "Business Account"
        },
        placeholders = {
            identifier = "Identifier"
        },
        status_labels = {
            pending = "Pending",
            paid = "Paid",
            cancelled = "Cancelled"
        }
    },
    job_invoice = {
        validation = {
            company_name_required = "Company name is required",
            company_address_required = "Company address is required",
            phone_required = "Phone number is required",
            valid_email_required = "Valid email address is required",
            org_number_required = "Organization number is required",
            customer_name_required = "Customer name is required",
            customer_address_required = "Customer address is required",
            customer_phone_required = "Customer phone is required",
            invoice_number_required = "Invoice number is required",
            invoice_date_required = "Invoice date is required",
            due_date_required = "Due date is required",
            description_required = "Description is required",
            quantity_min = "Quantity must be greater than 0",
            unit_price_min = "Unit price must be greater than 0",
            vat_rate_range = "VAT rate must be between 0-100%",
            min_one_line_required = "At least one line is required",
            payment_terms_required = "Payment terms are required",
            payment_method_required = "Payment method is required"
        },
        dialog = {
            title = "Create Business Invoice",
            description = "Generate and send professional invoices for your business",
            security_notice = {
                title = "Secure Invoice Management",
                description = "All business information is handled securely and sent directly from the system"
            }
        },
        tabs = {
            company = "Company",
            customer = "Customer",
            services = "Services",
            payment = "Payment"
        },
        sections = {
            company_info = {
                title = "Company Information",
                description = "Enter your company's contact details and organizational information"
            },
            services_products = {
                title = "Services and Products",
                description = "Add detailed lines for services or products"
            },
            payment_info = {
                title = "Payment Information",
                description = "Enter payment method and terms for the invoice"
            }
        },
        form = {
            company_name = "Company Name",
            company_address = "Company Address",
            company_phone = "Phone",
            company_email = "Email",
            org_number = "Organization Number",
            vat_number = "VAT Number",
            customer_name = "Customer Name",
            customer_company = "Company",
            customer_address = "Customer Address",
            customer_phone = "Customer Phone",
            customer_email = "Customer Email",
            invoice_number = "Invoice Number",
            invoice_date = "Invoice Date",
            due_date = "Due Date",
            project_reference = "Project Reference",
            payment_terms = "Payment Terms",
            payment_method = "Payment Method",
            bank_account = "Bank Account",
            notes = "Notes",
            add_line = "Add Line",
            quantity = "Quantity",
            unit_price = "Unit Price",
            vat_rate = "VAT Rate"
        },
        placeholders = {
            company_name = "Your Company Ltd",
            company_address = "Company Street 123\n123 45 Stockholm",
            customer_company = "Customer's Company Ltd",
            customer_address = "Customer Street 456\n123 45 Gothenburg",
            service_description = "Description of service or product"
        },
        descriptions = {
            vat_optional = "Optional - only for VAT registered companies",
            internal_reference = "Optional - for internal reference",
            bank_info = "Enter your bank giro or plus giro for payments",
            invoice_notes = "Optional information displayed on the invoice"
        },
        vat_options = {
            books_newspapers = "6% (Books, newspapers)"
        },
        footer = {
            due_date = "Due date: ",
            security_note = "Secure invoice management - no export possible"
        }
    },
    contacts = {
        header = {
            title = "Contacts",
            subtitle = "Manage your saved contacts for quick invoice creation"
        },
        add_form = {
            title = "Add Contact",
            subtitle = "Save frequently used player identifiers for quick access",
            identifier_label = "Player Identifier",
            identifier_placeholder = "steam:123456, license:abc123, char1:1234...",
            display_name_label = "Display Name",
            display_name_placeholder = "John Doe",
            button_add = "Add Contact",
            button_adding = "Adding..."
        },
        list = {
            title = "Your Contacts",
            subtitle = "Click on a contact to edit, or use the delete button to remove",
            search_placeholder = "Search contacts...",
            loading = "Loading contacts...",
            empty = {
                title = "No contacts saved yet",
                subtitle = "Add your first contact using the form on the left",
                description = "Add contacts above for quick invoice creation"
            },
            no_results = {
                title = "No matching contacts",
                subtitle = "Try adjusting your search terms"
            },
            added_date = "Added {date}"
        },
        actions = {
            edit = "Edit",
            delete = "Delete",
            save = "Save",
            cancel = "Cancel"
        },
        validation = {
            identifier_required = "Player identifier is required",
            identifier_invalid = "Invalid identifier format (must be type:value, e.g. steam:123456)",
            display_name_required = "Display name is required",
            display_name_min = "Display name must be at least 2 characters",
            display_name_max = "Display name must be less than 50 characters",
            contact_exists = "This contact already exists"
        },
        common = {
            ui = {
                loading = "Loading..."
            }
        },
        delete_dialog = {
            title = "Delete Contact",
            description = "Are you sure you want to delete \"{name}\"? This action cannot be undone.",
            cancel = "Cancel",
            confirm = "Delete"
        },
        manager = {
            select_title = "Select Contact",
            manage_title = "Manage Contacts",
            select_description = "Choose a contact to autofill the recipient information.",
            manage_description = "Add, edit, or delete your saved contacts for quick invoice creation.",
            select_button = "Select Contact",
            manage_button = "Manage Contacts",
            add_new = "Add New Contact",
            select_contact_button = "Select"
        }
    }
}
