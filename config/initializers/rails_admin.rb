RailsAdmin.config do |config|
  config.asset_source = :importmap

  config.parent_controller = "::ApplicationController"
  config.authenticate_with { authenticate_admin! }

  # All app models, without framework internals (SolidQueue, Turbo, ...)
  config.included_models = Dir[Rails.root.join("app/models/**/*.rb")]
    .reject { |file| file.include?("/concerns/") }
    .map { |file| file[%r{app/models/(.*)\.rb\z}, 1].camelize }
    .excluding("ApplicationRecord")

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
