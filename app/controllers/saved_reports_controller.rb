class SavedReportsController < ApplicationController
  include Authentication

  before_action :set_project
  before_action :set_report, only: [ :show, :destroy ]

  def index
    @reports = @project.saved_reports.recent
  end

  def create
    @report = @project.saved_reports.build(report_params)
    if @report.save
      redirect_back fallback_location: project_saved_reports_path(@project), notice: "Report saved."
    else
      redirect_back fallback_location: project_saved_reports_path(@project), alert: "Could not save report."
    end
  end

  def show
    config = @report.configuration
    case @report.report_type
    when "funnel"
      redirect_to funnels_project_path(@project, **config.symbolize_keys)
    when "retention"
      redirect_to retention_project_path(@project, **config.symbolize_keys)
    when "event_explorer"
      redirect_to event_explorer_project_path(@project, **config.symbolize_keys)
    else
      redirect_to @project
    end
  end

  def destroy
    @report.destroy
    redirect_to project_saved_reports_path(@project), notice: "Report deleted."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_report
    @report = @project.saved_reports.find(params[:id])
  end

  def report_params
    params.require(:saved_report).permit(:name, :report_type, configuration: {})
  end
end
