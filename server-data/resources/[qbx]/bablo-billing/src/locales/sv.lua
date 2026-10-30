
Locales['sv'] = {
    pagination = {
        showing = "Visar {start} till {end} av {total} resultat",
        items_per_page = "Objekt per sida",
        go_to_first = "Gå till första sidan",
        go_to_previous = "Gå till föregående sida",
        go_to_next = "Gå till nästa sida",
        go_to_last = "Gå till sista sidan",
        page = "Sida {page}",
        of_pages = "av {total} sidor"
    },
    sidebar = {
        header = {
            title = "Stadens Fakturering",
            subtitle = "Fakturering gjort enkelt"
        },
        routes = {
            dashboard = "Översikt",
            sent = "Skickade Fakturor",
            received = "Mottagna Fakturor",
            contacts = "Kontakter"
        },
        user_menu = {
            settings = "Inställningar",
            templates = "Mallar",
            profile = "Profil",
            personal_account = "Personligt Konto",
            job_account = "Jobbkonto",
            account_management = "Kontohantering"
        }
    },
    settings = {
        title = "Inställningar",
        subtitle = "Anpassa dina preferenser",
        theme = {
            title = "Tema",
            light = "Ljust",
            dark = "Mörkt",
            system = "System"
        },
        templates = {
            title = "Mallhantering",
            subtitle = "Hantera dina fakturamallar och förinställningar",
            manage_button = "Hantera Mallar",
            dialog_title = "Mallhantering",
            custom_title = "Anpassade Mallar",
            custom_count = "Du har {count} anpassade mallar",
            default_title = "Standardmallar",
            default_count = "{count} inbyggda mallar tillgängliga"
        }
    },
    userMenu = {
        settings = "Inställningar",
        templates = "Mallar",
        profile = "Profil",
        templateDialog = {
            title = "Mallhantering"
        }
    },
    dashboard = {},
    sent_invoices = {
        header = {
            title = "Skickade Fakturor",
            subtitle = "Här kan du se alla fakturor du har skickat till dina kunder. Du kan också hantera dem, kontrollera betalningsstatus och mer."
        },
        create_button = "Skapa Ny Faktura",
        loading = "Laddar skickade fakturor...",
        empty = "Inga skickade fakturor hittades.",
        tabs = {
            card = "Kortvy",
            table = "Tabellvy"
        },
        table = {
            title = "Fakturor",
            search_placeholder = "Sök efter fakturanummer, titel eller kund...",
            per_page = "sida",
            filter = {
                all = "Alla statusar",
                pending = "Väntande",
                paid = "Betald",
                cancelled = "Avbruten"
            },
            sort = {
                status = "Status",
                date = "Datum",
                amount = "Belopp",
                title = "Titel"
            },
            columns = {
                invoice_number = "Faktura #",
                title = "Titel",
                receiver = "Mottagare",
                date = "Datum",
                amount = "Belopp",
                status = "Status",
                actions = "Åtgärder"
            }
        },
        delete = {
            title = "Ta bort faktura",
            description = "Är du säker på att du vill ta bort fakturan \"{title}\" (#{id})? Denna åtgärd kan inte ångras.",
            success_title = "Faktura borttagen",
            success_description = "Fakturan har tagits bort framgångsrikt.",
            error_title = "Borttagning misslyckades",
            error_description = "Kunde inte ta bort fakturan. Försök igen."
        },
        statuses = {
            all = "Alla statusar",
            paid = "Betald",
            unpaid = "Obetald",
            pending = "Väntande"
        }
    },
    received_invoices = {
        end_of_list = "Alla fakturor laddade"
    },
    notifications = {
        invoice_received = {
            title = "Ny Faktura Mottagen",
            message = "Du har fått en ny faktura på {amount} kr från {sender}",
            simple = "Ny faktura mottagen på {amount} kr"
        },
        job_invoice_paid = {
            title = "Jobbfaktura Betald",
            message = "En jobbfaktura på {amount} kr har betalats för {job}",
            simple = "Jobbfaktura betald: {amount} kr"
        }
    },
    common = {
        descriptions = {
            invoice_paid = "Faktura Betald",
            invoice_payment = "Fakturabetalning"
        },
        ready = "Redo!",
        loading = {
            welcome = "Välkommen {name}",
            initializing = "Initialiserar system...",
            loading_data = "Laddar din data...",
            almost_ready = "Nästan klar..."
        },
        ui = {
            loading = "Laddar...",
            error = "Fel",
            view_all = "Visa Alla",
            not_available = "Ej tillgänglig"
        },
        actions = {
            view = "Visa",
            cancel = "Avbryt",
            creating = "Skapar...",
            save = "Spara",
            edit = "Redigera",
            delete = "Ta bort",
            deleting = "Tar bort...",
            confirm = "Bekräfta",
            close = "Stäng"
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
    create_invoice = {
        form = {
            multiple_items = {
                toggle_label = "Flera tjänster/produkter",
                toggle_description = "Aktivera för att lägga till flera saker på samma faktura (t.ex. bilreparationer, tuning, etc.)",
                amount_auto_calculated = "Beräknas automatiskt från raderna nedan",
                services_products_title = "Tjänster & Produkter",
                services_products_description = "Lägg till alla tjänster och produkter som ska faktureras",
                add_line = "Lägg till rad",
                line_number = "Rad {number}",
                description_label = "Beskrivning *",
                description_placeholder = "Beskrivning av tjänst eller produkt (t.ex. 'Motortuning', 'Däckbyte', etc.)",
                quantity_label = "Antal *",
                unit_price_label = "Enhetspris *",
                line_total = "Radtotal:",
                total_to_pay = "Totalt att betala:",
                details_label = "Detaljer:"
            },
            actions = {
                cancel = "Avbryt",
                creating = "Skapar...",
                sending = "Skickar...",
                send_invoice = "Skicka faktura"
            }
        },
        dialog = {
            personal = {
                title = "Skapa Ny Faktura",
                description = "Skicka en professionell faktura till en annan spelare",
                badge = "Personlig"
            }
        }
    },
    statuses = {
        all = "Alla statusar",
        paid = "Betald",
        unpaid = "Obetald",
        pending = "Väntande",
        cancelled = "Avbruten"
    },
    invoice_details = {
        types = {
            sent = "Skickad Faktura",
            received = "Mottagen Faktura"
        },
        descriptions = {
            sent = "Detaljer för skickad faktura",
            received = "Detaljer för mottagen faktura"
        },
        labels = {
            you = "Du",
            item = "artikel",
            items = "artiklar"
        },
        line_items = {
            title = "Fakturarader",
            description = "Beskrivning",
            qty = "Antal",
            quantity = "Antal",
            unit_price = "Enhetspris",
            total = "Totalt",
            footer = {
                based_on = "Baserat på",
                single_amount = "Enkelt beloppsfaktura"
            }
        },
        cards = {
            info = {
                title = "Fakturinformation",
                invoice_number = "Faktura #",
                status = "Status"
            },
            amount = {
                title = "Belopp",
                total = "Totalt Belopp"
            },
            involved = {
                title = "Involverade Parter",
                sender = "Avsändare",
                receiver = "Mottagare"
            },
            description = {
                title = "Beskrivning",
                details = "Detaljer"
            },
            line_items = {
                title = "Fakturarader",
                quantity = "Antal",
                unit_price = "Enhetspris",
                total = "Totalt"
            },
            date = {
                title = "Datum",
                created = "Skapad",
                due = "Förfallodatum"
            }
        }
    },
    contacts = {
        header = {
            title = "Kontakter",
            subtitle = "Hantera dina sparade kontakter för snabb fakturaskapning"
        },
        add_form = {
            title = "Lägg till Kontakt",
            subtitle = "Spara ofta använda spelaridentifierare för snabb åtkomst",
            identifier_label = "Spelaridentifierare",
            identifier_placeholder = "steam:123456, license:abc123, char1:1234...",
            display_name_label = "Visningsnamn",
            display_name_placeholder = "Johan Andersson",
            button_add = "Lägg till Kontakt",
            button_adding = "Lägger till..."
        },
        list = {
            title = "Dina Kontakter",
            subtitle = "Klicka på en kontakt för att redigera, eller använd ta bort-knappen",
            search_placeholder = "Sök kontakter...",
            loading = "Laddar kontakter...",
            empty = {
                title = "Inga kontakter sparade än",
                subtitle = "Lägg till din första kontakt med formuläret till vänster"
            },
            no_results = {
                title = "Inga matchande kontakter",
                subtitle = "Försök justera dina söktermer"
            },
            added_date = "Tillagd {date}"
        },
        actions = {
            edit = "Redigera",
            delete = "Ta bort",
            save = "Spara",
            cancel = "Avbryt"
        },
        validation = {
            identifier_required = "Spelaridentifierare krävs",
            identifier_invalid = "Ogiltigt identifierarformat (måste vara typ:värde, t.ex. steam:123456)",
            display_name_required = "Visningsnamn krävs",
            display_name_min = "Visningsnamn måste vara minst 2 tecken",
            display_name_max = "Visningsnamn måste vara mindre än 50 tecken",
            contact_exists = "Denna kontakt finns redan"
        },
        delete_dialog = {
            title = "Ta bort Kontakt",
            description = "Är du säker på att du vill ta bort \"{name}\"? Denna åtgärd kan inte ångras.",
            cancel = "Avbryt",
            confirm = "Ta bort"
        },
        manager = {
            select_title = "Välj Kontakt",
            manage_title = "Hantera Kontakter",
            select_description = "Välj en kontakt för att automatiskt fylla i mottagarinformation.",
            manage_description = "Lägg till, redigera eller ta bort dina sparade kontakter för snabb fakturaskapning.",
            select_button = "Välj Kontakt",
            manage_button = "Hantera Kontakter",
            add_new = "Lägg till Ny Kontakt",
            select_contact_button = "Välj"
        }
    }
}
