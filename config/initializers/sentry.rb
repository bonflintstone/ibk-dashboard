# Reports unhandled exceptions to the self-hosted Bugsink accessory (Sentry-compatible).
# No-ops unless SENTRY_DSN is set, so development and test stay silent.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = %i[active_support_logger http_logger]

    # Only report from production; never from dev/test.
    config.enabled_environments = %w[production]

    # Bugsink is an error tracker, not an APM — skip performance tracing.
    config.traces_sample_rate = 0.0

    # Don't ship request/user PII to the tracker.
    config.send_default_pii = false
  end
end
