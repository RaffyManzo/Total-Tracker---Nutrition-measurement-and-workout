# Local Database

SQLite will be the local database for Total Tracker.

Drift will provide the typed access layer for database queries and future persistence logic.

The schema will be defined after the existing Obsidian files have been analyzed. No hypothetical tables, DAOs, migrations, or seed data should be created during this setup phase.

The initial architecture is local-first. Online synchronization may be added later after the product requirements and data ownership rules are clear.
