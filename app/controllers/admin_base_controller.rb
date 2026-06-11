# Base controller for mounted admin engines (Mission Control – Jobs), gated by
# the same HTTP basic auth as /status and /admin.
class AdminBaseController < ActionController::Base
  include AdminAuthentication
  before_action :authenticate_admin!
end
