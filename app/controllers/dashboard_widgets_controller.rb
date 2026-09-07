class DashboardWidgetsController < ApplicationController
  include Authentication

  before_action :set_dashboard

  def create
    saved_report = @dashboard.project.saved_reports.find(params[:saved_report_id])
    @dashboard.pin(saved_report, range_days: range_days)
    redirect_to project_dashboard_path(@dashboard.project, @dashboard), notice: "Added to dashboard."
  end

  def update
    widget = @dashboard.dashboard_widgets.find(params[:id])
    widget.update(range_days: range_days)
    redirect_to project_dashboard_path(@dashboard.project, @dashboard)
  end

  def destroy
    @dashboard.dashboard_widgets.find(params[:id]).destroy
    redirect_to project_dashboard_path(@dashboard.project, @dashboard), notice: "Removed from dashboard."
  end

  private

  def range_days
    value = params[:range_days].to_i
    DashboardWidget::RANGE_OPTIONS.include?(value) ? value : DashboardWidget::DEFAULT_DAYS
  end

  def set_dashboard
    project = Project.find(params[:project_id])
    @dashboard = project.dashboards.find(params[:dashboard_id])
  end
end
