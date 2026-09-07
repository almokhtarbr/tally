class SegmentsController < ApplicationController
  include Authentication

  before_action :set_project
  before_action :set_segment, only: [ :show, :edit, :update, :destroy ]

  def index
    @segments = @project.segments.order(:name)
  end

  def show
    @user_count = @segment.user_count
    @users = @segment.matching_users
      .order(last_seen_at: :desc)
      .limit(50)
  end

  def new
    @segment = @project.segments.build
    @available_events = available_events
    @available_user_properties = available_user_properties
  end

  def create
    @segment = @project.segments.build(segment_params)
    if @segment.save
      redirect_to project_segment_path(@project, @segment), notice: "Segment created."
    else
      @available_events = available_events
      @available_user_properties = available_user_properties
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_events = available_events
    @available_user_properties = available_user_properties
  end

  def update
    if @segment.update(segment_params)
      redirect_to project_segment_path(@project, @segment), notice: "Segment updated."
    else
      @available_events = available_events
      @available_user_properties = available_user_properties
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @segment.destroy
    redirect_to project_segments_path(@project), notice: "Segment deleted."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_segment
    @segment = @project.segments.find(params[:id])
  end

  def segment_params
    params.require(:segment).permit(:name, :description, conditions: [ :type, :event, :operator, :days, :count, :key, :value ])
  end

  def available_events
    @project.event_daily_rollups.distinct.pluck(:event_name).sort
  end

  def available_user_properties
    @project.user_profiles
      .where.not(properties: {})
      .limit(100)
      .pluck(:properties)
      .flat_map(&:keys)
      .tally
      .sort_by { |_, c| -c }
      .first(20)
      .map(&:first)
  end
end
