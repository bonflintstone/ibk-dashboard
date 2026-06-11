module AdminAuthentication
  def authenticate_admin!
    authenticate_or_request_with_http_basic("ibk-dashboard admin") do |_username, password|
      ENV["ADMIN_PASSWORD"].present? &&
        ActiveSupport::SecurityUtils.secure_compare(password, ENV["ADMIN_PASSWORD"])
    end
  end
end
