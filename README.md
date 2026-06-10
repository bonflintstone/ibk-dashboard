# IBK-Dashboard

Events in Innsbruck as Dashboard through web scraping

Ich mag kein Instagram aber will trotzdem wissen was in Innsbuck so abgeht. Also hab ich diese Website gebastelt. Ich freu mich über Vorschläge, kann aber nur neue Organisationen hinzufügen wenn die Veranstaltungen auf einer Website gelistet werden und nicht nur Auf Insta. Montagu geht z.B. leider nicht.

## Setup

Rails 8 app, deployed with [Kamal](https://kamal-deploy.org) to https://ibk-dashboard.at (single server, Docker, SSL via kamal-proxy). All databases are SQLite files persisted in the `ibk_dashboard_2_storage` Docker volume (`storage/production*.sqlite3` — primary, cache, queue, cable).

### Scraping

Each venue has a scraper service in `app/services/` (e.g. `FetchTreibhaus`, `FetchBrux`, ...). `RefetchAll` deletes all scraped events and runs every scraper, then records a `RefetchEvent` (shown as "Last updated" on the page). Events submitted via the web form (`source: :webform`) are not touched by refetches.

### Background jobs

Jobs run on [Solid Queue](https://github.com/rails/solid_queue), which runs inside the Puma process (`SOLID_QUEUE_IN_PUMA: true` in `config/deploy.yml`, `plugin :solid_queue` in `config/puma.rb`) — no separate job container. Recurring schedule in `config/recurring.yml`:

- `refetch_events`: runs `RefetchJob` (→ `RefetchAll`) every day at 4am
- `clear_solid_queue_finished_jobs`: hourly cleanup of finished jobs

### Monitoring

https://ibk-dashboard.at/status shows:

- per-scraper health: every `RefetchAll` run records a `ScraperRun` per scraper (success/failure, scraped event count, duration, error class + message). A failing scraper does not abort the others, and its old events are kept (per-scraper transaction) instead of leaving the venue empty.
- Solid Queue health: supervisor/worker/dispatcher/scheduler heartbeats, the recurring schedule, and failed jobs with errors.
- weekly unique visitors (see below).

### Analytics

Privacy-friendly unique visitor counting, no cookies, no external service. Each dashboard request stores only a SHA256 digest of `(secret_key_base, week, ip, user agent)` (`Visit.track`). IP addresses are never stored, the digest rotates weekly so visitors can't be tracked across weeks, and obvious bots are skipped.

### Tests

```sh
bundle exec rspec
```

### Development

```sh
bin/setup
bin/dev
```

### Deployment

```sh
bin/kamal deploy
```

Useful aliases (see `config/deploy.yml`): `bin/kamal console`, `bin/kamal logs`, `bin/kamal shell`, `bin/kamal dbc`.
