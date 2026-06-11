class StatusController < ApplicationController
  before_action :authenticate_admin!

  def show
    @scrapers = RefetchAll.organizations.index_with do |scraper|
      runs = ScraperRun.where(scraper:).order(created_at: :desc)
      { last_run: runs.first, last_success: runs.success.first }
    end
    @refetch_event = RefetchEvent.order(created_at: :desc).first
    @weekly_visitors = Visit.group(:week).order(week: :desc).limit(12).count

    # Solid Queue lives in a separate database that only exists in
    # production, so these sections are skipped gracefully elsewhere.
    @queue_processes = solid_queue { SolidQueue::Process.order(:kind).to_a }
    @recurring_tasks = solid_queue { SolidQueue::RecurringTask.order(:key).to_a }
    @failed_jobs = solid_queue { SolidQueue::FailedExecution.order(created_at: :desc).limit(10).includes(:job).to_a }
  end

  def refetch
    organization = params[:organization].presence

    if organization && RefetchAll.organizations.exclude?(organization)
      return redirect_to status_path, alert: "Unknown organization: #{organization}"
    end

    organization ? RefetchJob.perform_later(organization) : RefetchJob.perform_later
    redirect_to status_path, notice: "Refetch enqueued for #{organization || "all scrapers"}"
  end

  private

  def solid_queue
    yield
  rescue ActiveRecord::ActiveRecordError
    nil
  end
end
