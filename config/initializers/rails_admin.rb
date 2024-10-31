RailsAdmin.config do |config|
  config.asset_source = :sprockets

  config.authenticate_with do
    authenticate_or_request_with_http_basic("Login required") do |username, password|
      username == "admin" && ActiveSupport::SecurityUtils.secure_compare(password, ENV["ADMIN_PASSWORD"])
    end
  end

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

  config.model Event do
    list do
      scopes [ nil, :published, :to_approve, :approved ]
    end
  end
end
