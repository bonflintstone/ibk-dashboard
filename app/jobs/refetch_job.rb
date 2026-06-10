class RefetchJob < ApplicationJob
  def perform(*args)
    RefetchAll.call
  end
end
