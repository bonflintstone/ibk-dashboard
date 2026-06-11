RailsAdmin.config do |config|
  config.asset_source = :importmap

  config.authenticate_with do
    authenticate_or_request_with_http_basic("ibk-dashboard admin") do |_username, password|
      ENV["ADMIN_PASSWORD"].present? &&
        ActiveSupport::SecurityUtils.secure_compare(password, ENV["ADMIN_PASSWORD"])
    end
  end

  config.included_models = %w[Event InstagramProfile ScraperRun RefetchEvent Visit]

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit
    delete
    show_in_app
  end
end
