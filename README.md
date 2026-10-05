### BiggestHits
* **Description:** Tracks, records, and logs the highest critical damage and healing numbers achieved by the player during sessions on the 2.5.3 client, offering milestone alerts.
* **How to Use:**
  1. Load the addon; it runs passively in the background.
  2. Type the associated summary command in chat to view your historical top records.
* **Known Issues & Gotchas:**
  * **Combat Log Overhead:** Relies heavily on parsing `COMBAT_LOG_EVENT_UNFILTERED`. In heavy 25-man raid scenarios, unoptimized event processing can create garbage collection pressure and frame stutter.
  * **Spell ID Ambiguity:** Multi-rank spells or items with proc effects can sometimes register duplicate or mislabeled entries if damage source IDs aren't normalized properly.
