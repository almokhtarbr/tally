class DashboardsController < ApplicationController
  include Authentication

  before_action :set_project
  before_action :set_dashboard, only: [ :show, :destroy ]

  def index
    @dashboards = @project.dashboards.recent
  end

  def show
    @widgets = @dashboard.dashboard_widgets.includes(:saved_report)
    @pinnable = @project.saved_reports.recent - @widgets.map(&:saved_report)
  end

  def create
    @dashboard = @project.dashboards.build(dashboard_params)
    if @dashboard.save
      redirect_to project_dashboard_path(@project, @dashboard), notice: "Dashboard created."
    else
      redirect_to project_dashboards_path(@project), alert: "Give the dashboard a name."
    end
  end

  def destroy
    @dashboard.destroy
    redirect_to project_dashboards_path(@project), notice: "Dashboard deleted."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_dashboard
    @dashboard = @project.dashboards.find(params[:id])
  end

  def dashboard_params
    params.require(:dashboard).permit(:name)
  end
end
