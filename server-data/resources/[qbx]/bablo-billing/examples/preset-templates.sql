-- =====================================================
-- BABLO BILLING - Invoice Template Presets
-- =====================================================
-- Run this SQL to import all default templates as server-wide defaults.
-- These rows use owner_identifier = '__SYSTEM__', which the script loads as the
-- built-in (read-only) templates for EVERY player. Add/edit/remove rows here to
-- change the in-game defaults (re-open the billing menu to see changes).
--
-- IMPORTANT: the "category" column must match the in-game JOB CATEGORY, not the
-- job name. Mapping: police->police, ambulance/ems/doctor->medical,
-- mechanic->mechanic, taxi/lawyer/realestate/cardealer->business,
-- judge/government->government. A preset whose category does not match a
-- player's job category will not appear for them.
--
-- You can modify amounts, descriptions, or remove
-- templates you don't want before running.
-- =====================================================

-- =====================================================
-- POLICE TEMPLATES (40 templates)
-- =====================================================

INSERT INTO bablo_billing_presets (owner_identifier, name, title, description, amount, category, created_at, updated_at) VALUES
('__SYSTEM__', 'Speeding Ticket', 'Traffic Violation - Speeding', 'Fine for exceeding the speed limit in a designated area.', 250.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Parking Violation', 'Parking Ticket', 'Fine for illegal parking in a restricted zone.', 150.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Reckless Driving', 'Traffic Violation - Reckless Driving', 'Fine for dangerous driving behavior endangering public safety.', 500.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Running a Red Light', 'Traffic Violation - Red Light', 'Fine for failing to stop at a red traffic signal.', 350.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Failure to Stop', 'Traffic Violation - Failure to Stop', 'Fine for failing to stop for a law enforcement officer.', 400.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Illegal Weapon Possession', 'Weapons Charge - Illegal Possession', 'Fine for possession of an illegal or unregistered weapon.', 2500.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Public Intoxication', 'Public Disorder - Intoxication', 'Fine for being intoxicated in a public area.', 200.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Vandalism', 'Property Damage - Vandalism', 'Fine for willful destruction or damage to property.', 750.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Assault Fine', 'Violent Crime - Assault', 'Fine for physical assault on another person.', 1500.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'No Seatbelt', 'Traffic Violation - Seatbelt', 'Fine for driving or riding without wearing a seatbelt.', 100.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Driving Without License', 'Traffic Violation - No License', 'Fine for operating a vehicle without a valid driver''s license.', 450.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Illegal U-Turn', 'Traffic Violation - Illegal U-Turn', 'Fine for making an illegal U-turn in a prohibited area.', 200.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Trespassing', 'Property Crime - Trespassing', 'Fine for unlawfully entering private or restricted property.', 500.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Drug Possession', 'Drug Charge - Possession', 'Fine for possession of illegal controlled substances.', 1800.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Resisting Arrest', 'Obstruction - Resisting Arrest', 'Fine for resisting or obstructing a lawful arrest.', 1200.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Hit and Run', 'Traffic Crime - Hit and Run', 'Fine for leaving the scene of an accident without stopping.', 2000.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Jaywalking', 'Pedestrian Violation', 'Fine for crossing the road outside designated crosswalks.', 75.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Noise Violation', 'Public Disturbance - Noise', 'Fine for excessive noise disturbing the peace.', 150.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Robbery Fine', 'Violent Crime - Robbery', 'Fine for theft using force or threat of force.', 5000.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Evading Police', 'Traffic Crime - Evading', 'Fine for fleeing from law enforcement in a vehicle.', 3500.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'DUI/DWI', 'Traffic Crime - Driving Under Influence', 'Fine for driving under the influence of alcohol or drugs.', 2500.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Stolen Vehicle', 'Vehicle Theft', 'Fine for operating a stolen vehicle.', 4000.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Kidnapping', 'Violent Crime - Kidnapping', 'Fine for unlawful restraint or kidnapping of a person.', 8000.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Brandishing Weapon', 'Weapons Charge - Brandishing', 'Fine for displaying or brandishing a weapon in public.', 800.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Discharging Firearm', 'Weapons Charge - Discharge', 'Fine for illegally discharging a firearm in city limits.', 1500.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Fraud', 'Financial Crime - Fraud', 'Fine for committing fraud or financial deception.', 3000.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Attempted Bribery', 'Corruption - Bribery', 'Fine for attempting to bribe a public official.', 2000.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Obstruction of Justice', 'Obstruction - Justice', 'Fine for interfering with a police investigation.', 1000.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Loitering', 'Public Order - Loitering', 'Fine for loitering in a prohibited area.', 100.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Illegal Street Racing', 'Traffic Crime - Street Racing', 'Fine for participating in illegal street racing.', 2500.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Expired Registration', 'Traffic Violation - Registration', 'Fine for operating a vehicle with expired registration.', 250.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'No Insurance', 'Traffic Violation - No Insurance', 'Fine for driving without valid vehicle insurance.', 500.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Illegal Window Tint', 'Vehicle Violation - Window Tint', 'Fine for vehicle windows tinted beyond legal limits.', 150.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Broken Taillight', 'Vehicle Violation - Equipment', 'Fine for operating a vehicle with broken lights or equipment.', 100.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Attempted Murder', 'Violent Crime - Attempted Murder', 'Fine for attempted murder or assault with intent to kill.', 15000.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Arson', 'Property Crime - Arson', 'Fine for intentionally setting fire to property.', 6000.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Burglary', 'Property Crime - Burglary', 'Fine for breaking and entering with intent to commit crime.', 3500.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Outstanding Warrant', 'Warrant - Felony', 'Additional fine for arrest on outstanding felony warrant.', 5000.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Misdemeanor Warrant', 'Warrant - Misdemeanor', 'Additional fine for arrest on outstanding misdemeanor warrant.', 1500.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Drug Trafficking', 'Drug Charge - Trafficking', 'Fine for distribution or trafficking of controlled substances.', 10000.00, 'police', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000);

-- =====================================================
-- AMBULANCE TEMPLATES (30 templates)
-- =====================================================

INSERT INTO bablo_billing_presets (owner_identifier, name, title, description, amount, category, created_at, updated_at) VALUES
('__SYSTEM__', 'Medical Treatment', 'Emergency Medical Services', 'Cost for emergency medical treatment and ambulance services.', 1200.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Surgery', 'Surgical Procedure', 'Cost for surgical intervention and post-operative care.', 5000.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Prescription Medication', 'Pharmacy Services', 'Cost for prescribed medications and pharmaceutical services.', 300.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Physical Therapy', 'Rehabilitation Services', 'Cost for physical therapy and rehabilitation sessions.', 800.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Consultation Fee', 'Medical Consultation', 'Fee for medical consultation and examination.', 250.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'X-Ray/Imaging', 'Diagnostic Imaging', 'Cost for X-ray, CT scan, MRI, or other diagnostic imaging services.', 600.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Ambulance Transport', 'Emergency Transport', 'Cost for emergency ambulance transportation to medical facility.', 800.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Wound Treatment', 'Wound Care Services', 'Cost for cleaning, stitching, and treating wounds.', 350.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Blood Transfusion', 'Blood Services', 'Cost for blood transfusion and related services.', 1500.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'ICU Stay', 'Intensive Care Unit', 'Cost for intensive care unit monitoring and treatment.', 3500.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Psychiatric Evaluation', 'Mental Health Services', 'Cost for psychiatric evaluation and mental health assessment.', 500.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Revival/Resuscitation', 'Emergency Revival', 'Cost for emergency resuscitation and life-saving procedures.', 2000.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'General Checkup', 'Routine Medical Checkup', 'Cost for routine health examination and vital signs check.', 150.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Bandage/First Aid', 'First Aid Services', 'Cost for basic first aid, bandaging, and minor treatment.', 100.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Broken Bone Treatment', 'Fracture Care', 'Cost for treating and setting broken bones with cast/splint.', 1200.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Gunshot Wound', 'Trauma - Gunshot', 'Cost for treating gunshot wounds and bullet extraction.', 2500.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Stab Wound', 'Trauma - Stab Wound', 'Cost for treating stab wounds and lacerations.', 1800.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Overdose Treatment', 'Emergency - Overdose', 'Cost for treating drug or alcohol overdose.', 1500.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Burn Treatment', 'Burn Care Services', 'Cost for treating burn injuries and skin grafts.', 2000.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Concussion Treatment', 'Head Injury Care', 'Cost for concussion diagnosis and treatment.', 800.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Vehicle Accident Injury', 'Trauma - Vehicle Accident', 'Cost for treating injuries from vehicle accidents.', 2200.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Medical Airlift', 'Helicopter Transport', 'Cost for emergency helicopter medical transport.', 5000.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Stitches', 'Wound Closure', 'Cost for suturing and closing wounds with stitches.', 400.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'IV Fluid Treatment', 'Intravenous Therapy', 'Cost for IV fluid administration and hydration therapy.', 300.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Defibrillation', 'Cardiac Emergency', 'Cost for defibrillator use and cardiac emergency response.', 1500.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Oxygen Therapy', 'Respiratory Support', 'Cost for oxygen administration and respiratory support.', 250.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Splint Application', 'Immobilization', 'Cost for applying splints to immobilize injuries.', 200.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Pain Management', 'Pain Relief', 'Cost for pain relief medication and management.', 150.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Emergency Room Visit', 'ER Services', 'Base cost for emergency room admission and triage.', 500.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Adrenaline Shot', 'Emergency Injection', 'Cost for emergency adrenaline or epinephrine injection.', 350.00, 'medical', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000);

-- =====================================================
-- MECHANIC TEMPLATES (30 templates)
-- =====================================================

INSERT INTO bablo_billing_presets (owner_identifier, name, title, description, amount, category, created_at, updated_at) VALUES
('__SYSTEM__', 'Vehicle Repair', 'Vehicle Maintenance & Repair', 'Cost for vehicle repair services including parts and labor.', 800.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Towing Service', 'Vehicle Towing', 'Cost for towing services and vehicle recovery.', 300.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Engine Repair', 'Engine Maintenance & Repair', 'Cost for engine diagnostics, repair, and parts replacement.', 1500.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Tire Change', 'Tire Replacement Service', 'Cost for tire replacement, balancing, and alignment.', 400.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Paint Job', 'Vehicle Paint Service', 'Cost for vehicle painting and bodywork.', 600.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Custom Modifications', 'Vehicle Customization', 'Cost for custom modifications and performance upgrades.', 2000.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Vehicle Inspection', 'Safety Inspection', 'Fee for comprehensive vehicle safety inspection.', 200.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Oil Change', 'Oil & Filter Service', 'Cost for oil change and filter replacement service.', 150.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Brake Service', 'Brake Repair & Replacement', 'Cost for brake pad replacement, rotor service, and brake system repair.', 500.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Transmission Repair', 'Transmission Service', 'Cost for transmission repair, fluid change, and maintenance.', 2500.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Window Tinting', 'Window Tint Service', 'Cost for professional window tinting installation.', 350.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Car Wash & Detail', 'Detailing Service', 'Cost for full vehicle wash, interior cleaning, and detailing.', 250.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Battery Replacement', 'Battery Service', 'Cost for battery testing, replacement, and installation.', 200.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Suspension Repair', 'Suspension Service', 'Cost for suspension system repair and replacement parts.', 1200.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Exhaust System', 'Exhaust Repair & Upgrade', 'Cost for exhaust system repair, replacement, or performance upgrade.', 800.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Body Repair', 'Collision & Body Work', 'Cost for dent removal, body panel repair, and collision damage.', 1800.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Performance Tuning', 'Engine Tuning Service', 'Cost for ECU tuning and performance optimization.', 1000.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Wheel Alignment', 'Alignment Service', 'Cost for wheel alignment and steering adjustment.', 150.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'AC Repair', 'Air Conditioning Service', 'Cost for AC system repair and recharge.', 450.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Radiator Service', 'Cooling System Repair', 'Cost for radiator repair and coolant flush.', 350.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Headlight Repair', 'Lighting Service', 'Cost for headlight repair or replacement.', 200.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Windshield Replacement', 'Glass Service', 'Cost for windshield repair or replacement.', 500.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Turbo Installation', 'Performance Upgrade', 'Cost for turbocharger installation and tuning.', 3500.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'NOS Installation', 'Nitrous System', 'Cost for nitrous oxide system installation.', 2000.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Lowrider Hydraulics', 'Hydraulic System', 'Cost for hydraulic suspension system installation.', 4000.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Sound System Install', 'Audio Installation', 'Cost for car audio system installation.', 800.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Fuel System Repair', 'Fuel Service', 'Cost for fuel pump, filter, or injector repair.', 600.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Clutch Replacement', 'Clutch Service', 'Cost for clutch replacement and adjustment.', 900.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Spark Plug Change', 'Ignition Service', 'Cost for spark plug replacement and ignition tune-up.', 100.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Full Engine Swap', 'Engine Replacement', 'Cost for complete engine swap and installation.', 8000.00, 'mechanic', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000);

-- =====================================================
-- TAXI TEMPLATES (25 templates)
-- =====================================================

INSERT INTO bablo_billing_presets (owner_identifier, name, title, description, amount, category, created_at, updated_at) VALUES
('__SYSTEM__', 'Taxi Ride (Short)', 'Short Distance Fare', 'Fare for short distance taxi transportation within the city.', 50.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Taxi Ride (Medium)', 'Medium Distance Fare', 'Fare for medium distance taxi transportation across town.', 150.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Taxi Ride (Long)', 'Long Distance Fare', 'Fare for long distance taxi transportation to remote areas.', 300.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Airport Transfer', 'Airport Transportation', 'Fixed fare for airport pickup or dropoff service.', 250.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'VIP Transport', 'Executive Transportation', 'Premium fare for VIP or executive transportation service.', 500.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Tour Guide Service', 'City Tour', 'Fee for guided city tour and sightseeing service.', 200.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Waiting Fee', 'Taxi Waiting Charge', 'Additional charge for taxi waiting time during stops.', 25.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Late Night Surcharge', 'Night Fare', 'Additional fee for late night taxi service.', 50.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Express Pickup', 'Priority Service', 'Premium fee for immediate priority pickup.', 75.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Group Transport', 'Multiple Passengers', 'Fare for transporting a group of passengers.', 200.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Hospital Run', 'Medical Transport', 'Fare for non-emergency transport to medical facility.', 100.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Court Transport', 'Legal Appointment', 'Fare for transport to courthouse or legal appointments.', 120.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Bank Run', 'Financial District', 'Fare for transport to bank or financial institutions.', 80.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Shopping Trip', 'Retail Transport', 'Fare for transport to shopping areas with wait time.', 100.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Event Transport', 'Special Event', 'Fare for transport to concerts, sports, or special events.', 150.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Beach Trip', 'Coastal Transport', 'Fare for transport to beach or coastal areas.', 180.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Mountain Trip', 'Scenic Route', 'Fare for transport to mountain or scenic locations.', 250.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Cross-City Express', 'City to City', 'Fare for express transport across different city zones.', 350.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Charter Service', 'Hourly Rental', 'Hourly rate for private taxi charter service.', 100.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Delivery Run', 'Package Transport', 'Fee for small package delivery by taxi.', 60.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Pet Transport', 'Animal Friendly', 'Additional fee for transporting pets.', 30.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Luggage Handling', 'Extra Baggage', 'Fee for handling extra luggage or large items.', 20.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Fuel Surcharge', 'Gas Price Adjustment', 'Additional fee during high fuel price periods.', 15.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Cancellation Fee', 'Booking Cancellation', 'Fee charged for last-minute ride cancellation.', 25.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('__SYSTEM__', 'Cleanup Fee', 'Vehicle Cleaning', 'Fee for excessive mess or vehicle cleaning required.', 100.00, 'business', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000);

-- =====================================================
-- TOTAL: 125 templates
-- - Police: 40
-- - Ambulance: 30
-- - Mechanic: 30
-- - Taxi: 25
-- =====================================================
