// Suites share one database and explicitly drain the global achievement queue.
// Keep automatic polling off at app startup, even when local .env enables it.
process.env.ACHIEVEMENTS_ENABLED = 'false';
