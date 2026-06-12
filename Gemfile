source "https://rubygems.org"

gem "bootsnap", require: false
gem "dotenv-rails", "~> 3.1"
gem "httparty", "~> 0.22.0"
gem "typhoeus", "~> 1.4" # Instagram scraping: Meta blocks Ruby net/http's TLS fingerprint
gem "importmap-rails"
gem "jbuilder"
gem "propshaft"
gem "puma", ">= 5.0"
gem "rails", "~> 8.0.0"
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"
gem "sqlite3", ">= 2.1"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "thruster", require: false
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "brakeman", require: false
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
  gem "kamal", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

gem "rspec-rails", "~> 8.0", :groups => [:development, :test]

gem "anthropic", "~> 1.48"

gem "rails_admin", "~> 3.3"

gem "rails-i18n", "~> 8.1"
gem "rails_admin-i18n", "~> 1.20"

# Web dashboard for Solid Queue jobs (admin-gated at /jobs)
gem "mission_control-jobs", "~> 1.0"

# QR codes for the bookmark-sync share modal
gem "rqrcode", "~> 2.2"
