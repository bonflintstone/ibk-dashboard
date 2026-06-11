RailsAdmin.config do |config|
  config.asset_source = :importmap

  config.parent_controller = "::ApplicationController"
  config.authenticate_with { authenticate_admin! }

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
