class ReviewEventJob < ApplicationJob
  discard_on ActiveJob::DeserializationError # event was deleted before review

  def perform(event)
    ReviewEvent.call(event)
  end
end
