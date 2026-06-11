class RefetchJob < ApplicationJob
  def perform(organization = nil)
    if organization
      RefetchAll.refetch(organization)
    else
      RefetchAll.call
    end
  end
end
