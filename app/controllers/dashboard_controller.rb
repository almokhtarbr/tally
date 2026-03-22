class DashboardController < ApplicationController
  include Authentication

  def index
    @projects = Project.order(created_at: :desc)
  end
end
