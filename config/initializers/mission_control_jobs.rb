# Reuse the app's ADMIN_PASSWORD basic auth (via AdminBaseController) instead of
# Mission Control's own credentials.
Rails.application.config.to_prepare do
  MissionControl::Jobs.base_controller_class = "AdminBaseController"
end
MissionControl::Jobs.http_basic_auth_enabled = false
