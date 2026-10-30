// Built-in fallbacks ensure every police report type has a usable template.
// A configured server template for the same type takes precedence.
export const DEFAULT_REPORT_TEMPLATES = [
	{
		id: -1, name: "Standard Incident", type: "Incident Report",
		content: `<h2>Incident Summary</h2><p>Date / time: [DATE AND TIME]</p><p>Location: [LOCATION]</p><p>Reporting officer: [NAME / CALLSIGN]</p><h2>Parties Involved</h2><p>Suspects: [NAMES / IDS]</p><p>Victims / witnesses: [NAMES / CONTACTS]</p><h2>Narrative</h2><p>[Describe the incident in chronological order, including observations and statements.]</p><h2>Evidence</h2><ul><li>[Evidence collected and storage location]</li></ul><h2>Actions Taken</h2><p>[Arrests, citations, medical assistance and follow-up.]</p><h2>Disposition</h2><p>[Outcome / case status]</p>`,
	},
	{
		id: -2, name: "Standard Traffic", type: "Traffic Report",
		content: `<h2>Traffic Incident</h2><p>Date / time: [DATE AND TIME]</p><p>Location: [ROAD / INTERSECTION]</p><p>Officer: [NAME / CALLSIGN]</p><h2>Vehicles and Drivers</h2><p>Vehicle 1: [MODEL / COLOUR / PLATE / DRIVER]</p><p>Vehicle 2: [MODEL / COLOUR / PLATE / DRIVER]</p><h2>Circumstances</h2><p>[Reason for stop or collision details, direction of travel, speed, weather and road conditions.]</p><h2>Injuries and Damage</h2><p>[Injuries, damage, EMS response and towing.]</p><h2>Statements and Evidence</h2><p>[Witness statements, photographs, footage and observations.]</p><h2>Enforcement and Outcome</h2><p>[Violations, citations, arrests and final disposition.]</p>`,
	},
	{
		id: -3, name: "Full Investigation", type: "Investigation Report",
		content: `<h2>Investigation Overview</h2><p>Case reference: [CASE NUMBER]</p><p>Lead investigator: [NAME / CALLSIGN]</p><p>Date opened: [DATE]</p><h2>Background</h2><p>[Reason for investigation and related reports.]</p><h2>Persons of Interest</h2><p>[Names, identifiers and relevance.]</p><h2>Timeline</h2><ul><li>[DATE / TIME — EVENT]</li></ul><h2>Evidence and Interviews</h2><p>[Evidence, interview summaries, sources and findings.]</p><h2>Findings</h2><p>[Established facts and outstanding questions.]</p><h2>Recommendations</h2><p>[Further enquiries, proposed charges and case status.]</p>`,
	},
	{
		id: -4, name: "Standard Arrest", type: "Arrest Report",
		content: `<h2>Arrest Summary</h2><p>Date / time: [DATE AND TIME]</p><p>Location: [LOCATION]</p><p>Arresting officer: [NAME / CALLSIGN]</p><h2>Suspect Information</h2><p>Name / State ID: [NAME / ID]</p><h2>Probable Cause</h2><p>[Facts and observations supporting the arrest.]</p><h2>Narrative</h2><p>[Chronological account of events and officer actions.]</p><h2>Charges</h2><ul><li>[CHARGE / CODE / COUNT]</li></ul><h2>Evidence Seized</h2><ul><li>[ITEM / SERIAL / STORAGE]</li></ul><h2>Rights and Statements</h2><p>[Rights advised, time, response and any statements.]</p><h2>Processing</h2><p>[Booking location, medical treatment, sentence / fine and disposition.]</p>`,
	},
	{
		id: -5, name: "Evidence Collection", type: "Evidence Report",
		content: `<h2>Evidence Summary</h2><p>Related case / report: [REFERENCE]</p><p>Collecting officer: [NAME / CALLSIGN]</p><p>Date / time: [DATE AND TIME]</p><p>Location: [COLLECTION SITE]</p><h2>Evidence Items</h2><ul><li>[ITEM / DESCRIPTION / SERIAL / CONDITION]</li></ul><h2>Collection and Storage</h2><p>[Exact recovery location, collection method, packaging and locker / stash.]</p><h2>Chain of Custody</h2><ul><li>[DATE / TIME — FROM / TO — ACTION]</li></ul><h2>Analysis Requested</h2><p>[Tests requested and results when available.]</p><h2>Additional Notes</h2><p>[Relevant observations and attachments.]</p>`,
	},
];
