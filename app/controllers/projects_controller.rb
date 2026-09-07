require "csv"

class ProjectsController < ApplicationController
  include Authentication
  include Auditable

  before_action :set_project, only: [ :show, :edit, :update, :destroy, :api_keys, :errors, :error_detail,
    :event_explorer, :user_profile, :funnels, :retention, :users, :export_csv, :user_paths, :forms, :anomalies,
    :share, :unshare, :audit ]

  SYSTEM_EVENTS = %w[$session_start $session_end $outbound_click $dead_click $click $rage_click $form_submit $input_change $field_time $scroll_depth $page_leave $error $promise_error $network_error $server_error $copy $resize].freeze

  def index
    @projects = Project.order(created_at: :desc)
  end

  def show
    set_date_range
    range_days = (@to - @from).to_i + 1
    prev_from = @from - range_days.days
    prev_to = @from - 1.day

    current_range = @from..@to
    prev_range = prev_from..prev_to
    current_time_range = @current_time_range
    prev_time_range = prev_from.beginning_of_day..prev_to.end_of_day

    current_rollups = @project.event_daily_rollups.where(date: current_range)
    prev_rollups = @project.event_daily_rollups.where(date: prev_range)

    @visitors = @project.events
      .where(occurred_at: current_time_range)
      .where.not(name: SYSTEM_EVENTS)
      .select("COALESCE(properties->>'anonymous_id', user_profile_id::text)").distinct.count
    @prev_visitors = @project.events
      .where(occurred_at: prev_time_range)
      .where.not(name: SYSTEM_EVENTS)
      .select("COALESCE(properties->>'anonymous_id', user_profile_id::text)").distinct.count

    @pageviews = current_rollups.where(event_name: "$pageview").sum(:count)
    @prev_pageviews = prev_rollups.where(event_name: "$pageview").sum(:count)

    @custom_events = current_rollups.where.not(event_name: SYSTEM_EVENTS + [ "$pageview" ]).sum(:count)
    @prev_custom_events = prev_rollups.where.not(event_name: SYSTEM_EVENTS + [ "$pageview" ]).sum(:count)

    @sessions = current_rollups.where(event_name: "$session_start").sum(:count)
    @prev_sessions = prev_rollups.where(event_name: "$session_start").sum(:count)

    session_durations = @project.events
      .where(name: "$session_end", occurred_at: current_time_range)
      .pluck(Arel.sql("(properties->>'duration_seconds')::int"))
      .compact
    @avg_duration = session_durations.any? ? (session_durations.sum.to_f / session_durations.size).round : 0

    session_page_counts = @project.events
      .where(name: "$session_end", occurred_at: current_time_range)
      .pluck(Arel.sql("(properties->>'pages_viewed')::int"))
      .compact
    @bounce_rate = session_page_counts.any? ? ((session_page_counts.count { |c| c <= 1 }.to_f / session_page_counts.size) * 100).round : 0

    @daily_pageviews = current_rollups
      .where(event_name: "$pageview")
      .group(:date).sum(:count)
    @daily_custom = current_rollups
      .where.not(event_name: SYSTEM_EVENTS + [ "$pageview" ])
      .group(:date).sum(:count)
    @chart_dates = (@from..@to).map(&:to_s)

    @top_custom_events = current_rollups
      .where.not(event_name: SYSTEM_EVENTS + [ "$pageview" ])
      .group(:event_name).sum(:count)
      .sort_by { |_, count| -count }
      .first(10)

    @top_pages = @project.events
      .where(name: "$pageview", occurred_at: current_time_range)
      .pluck(Arel.sql("properties->>'path' as path"))
      .compact.reject(&:blank?)
      .tally
      .sort_by { |_, count| -count }
      .first(10)

    @top_referrers = @project.events
      .where(name: "$session_start", occurred_at: current_time_range)
      .pluck(Arel.sql("properties->>'referrer' as ref"))
      .compact.reject(&:blank?)
      .map { |r| URI.parse(r).host rescue r }
      .tally
      .sort_by { |_, count| -count }
      .first(5)

    @active_users = @project.user_profiles
      .where.not(last_seen_at: nil)
      .order(last_seen_at: :desc)
      .limit(10)

    @recent_events = @project.events
      .chronological.limit(30)
      .includes(:user_profile)

    @click_count = @project.events.where(name: "$click", occurred_at: current_time_range).count
    @rage_clicks = @project.events.where(name: "$rage_click", occurred_at: current_time_range).count
    @dead_clicks = @project.events.where(name: "$dead_click", occurred_at: current_time_range).count
    @form_submits = @project.events.where(name: "$form_submit", occurred_at: current_time_range).count
    @js_errors = @project.events.where(name: [ "$error", "$promise_error", "$server_error" ], occurred_at: current_time_range).count
    @daily_errors_sparkline = current_rollups
      .where(event_name: [ "$error", "$promise_error", "$server_error" ])
      .group(:date).sum(:count)

    @active_anomalies = @project.anomalies.active.recent.limit(5)

    @top_clicks = @project.events
      .where(name: "$click", occurred_at: current_time_range)
      .pluck(Arel.sql("COALESCE(properties->>'text', properties->>'selector') as el"))
      .compact.reject(&:blank?)
      .tally
      .sort_by { |_, c| -c }
      .first(8)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    if @project.save
      audit!(@project, "project.create", "Created the project")
      redirect_to @project, notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @project.update(project_params)
      changed = @project.saved_changes.except("updated_at", "created_at").keys
      audit!(@project, "project.update", "Updated #{changed.to_sentence}", fields: changed) if changed.any?
      redirect_to @project, notice: "Project updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project deleted."
  end

  # Enable (or rotate) the public read-only dashboard link.
  def share
    @project.enable_sharing!
    audit!(@project, "project.share_on", "Turned the public dashboard link on")
    redirect_to api_keys_project_path(@project), notice: "Public dashboard link is on."
  end

  def unshare
    @project.disable_sharing!
    audit!(@project, "project.share_off", "Turned the public dashboard link off")
    redirect_to api_keys_project_path(@project), notice: "Public dashboard link is off."
  end

  def api_keys; end

  def audit
    @audit_events = @project.audit_events.recent.includes(:user).limit(200)
  end

  def event_explorer
    set_date_range
    @available_events = @project.event_daily_rollups
      .where.not(event_name: SYSTEM_EVENTS)
      .distinct.pluck(:event_name).sort

    @metric = params[:metric] || "total"
    @group_by = params[:group_by].presence
    @second_group_by = params[:second_group_by].presence
    @page = [ params[:page].to_i, 1 ].max
    per_page = 50

    base_events = @project.events
      .where(occurred_at: @current_time_range)
      .where.not(name: SYSTEM_EVENTS)

    base_events = base_events.where(name: params[:event_name]) if params[:event_name].present?

    if params[:prop_key].present? && params[:prop_value].present?
      base_events = base_events.where("properties->>? ILIKE ?", params[:prop_key], "%#{params[:prop_value]}%")
    end

    @total_count = base_events.count
    @unique_users_count = base_events.where.not(user_profile_id: nil).select(:user_profile_id).distinct.count

    if @metric == "unique_users"
      @daily_counts = base_events
        .where.not(user_profile_id: nil)
        .group(Arel.sql("occurred_at::date"))
        .select(Arel.sql("occurred_at::date as date, COUNT(DISTINCT user_profile_id) as count"))
        .map { |r| [ r.date, r.count ] }.to_h
    elsif params[:prop_key].blank? && params[:event_name].present?
      @daily_counts = @project.event_daily_rollups
        .where(date: @from..@to, event_name: params[:event_name])
        .group(:date).sum(:count)
    elsif params[:prop_key].blank? && params[:event_name].blank?
      @daily_counts = @project.event_daily_rollups
        .where(date: @from..@to)
        .where.not(event_name: SYSTEM_EVENTS)
        .group(:date).sum(:count)
    else
      @daily_counts = base_events.group(Arel.sql("occurred_at::date")).count
    end

    if @group_by.present?
      @group_by_breakdown = base_events
        .where("properties->>? IS NOT NULL", @group_by)
        .group(Arel.sql("properties->>#{ActiveRecord::Base.connection.quote(@group_by)}"))
        .count
        .sort_by { |_, c| -c }
        .first(10)

      top_values = @group_by_breakdown.first(5).map(&:first)
      @group_by_daily = {}
      top_values.each do |val|
        @group_by_daily[val] = base_events
          .where("properties->>? = ?", @group_by, val)
          .group(Arel.sql("occurred_at::date")).count
      end

      if @second_group_by.present?
        @multi_breakdown = {}
        top_values.each do |primary_val|
          @multi_breakdown[primary_val] = base_events
            .where("properties->>? = ?", @group_by, primary_val)
            .where("properties->>? IS NOT NULL", @second_group_by)
            .group(Arel.sql("properties->>#{ActiveRecord::Base.connection.quote(@second_group_by)}"))
            .count
            .sort_by { |_, c| -c }
            .first(5)
        end
      end
    end

    @available_properties = @project.events
      .where(occurred_at: @current_time_range)
      .where.not(name: SYSTEM_EVENTS)
      .limit(100)
      .pluck(:properties)
      .flat_map(&:keys)
      .reject { |k| k == "anonymous_id" }
      .tally
      .sort_by { |_, c| -c }
      .first(20)
      .map(&:first)

    @events = base_events.chronological
      .offset((@page - 1) * per_page)
      .limit(per_page + 1)
      .includes(:user_profile)

    @has_next = @events.size > per_page
    @events = @events.first(per_page)
    @total_pages = (@total_count.to_f / per_page).ceil
  end

  def user_profile
    set_date_range
    @user = @project.user_profiles.find(params[:user_profile_id])

    @total_events = @user.events.where.not(name: SYSTEM_EVENTS).count
    @events_in_range = @user.events.where(occurred_at: @current_time_range).where.not(name: SYSTEM_EVENTS).count
    @sessions_count = @user.events.where(name: "$session_start", occurred_at: @current_time_range).count

    @daily_activity = @user.events
      .where(occurred_at: @current_time_range)
      .where.not(name: SYSTEM_EVENTS)
      .group(Arel.sql("occurred_at::date")).count

    @event_breakdown = @user.events
      .where(occurred_at: @current_time_range)
      .where.not(name: SYSTEM_EVENTS)
      .group(:name).count
      .sort_by { |_, c| -c }
      .first(10)

    @recent_sessions = build_user_sessions(@user)

    @page = [ params[:page].to_i, 1 ].max
    per_page = 50
    @timeline_events = @user.events
      .where(occurred_at: @current_time_range)
      .chronological
      .offset((@page - 1) * per_page)
      .limit(per_page + 1)

    @has_next = @timeline_events.size > per_page
    @timeline_events = @timeline_events.first(per_page)

    @grouped_timeline = group_events_by_session(@timeline_events)
  end

  def funnels
    set_date_range
    @available_events = @project.event_daily_rollups
      .where.not(event_name: SYSTEM_EVENTS)
      .distinct.pluck(:event_name).sort

    @steps = Array(params[:steps]).reject(&:blank?).first(10)
    @window = params[:window] || "unlimited"

    @filter_prop_key = params[:filter_prop_key].presence
    @filter_prop_value = params[:filter_prop_value].presence
    @filter_prop_type = params[:filter_prop_type] || "event" # "event" or "user"

    @segment_id = params[:segment_id].presence
    @segments = @project.segments.order(:name)

    @saved_funnels = @project.saved_reports.by_type("funnel").recent

    @funnel_results = compute_funnel(@steps, @window) if @steps.size >= 2

    if @funnel_results.present? && @funnel_results.size >= 2
      @overall_conversion = @funnel_results.last[:total_pct]
      @entered = @funnel_results.first[:count]
      @completed = @funnel_results.last[:count]
    end

    @available_event_properties = extract_available_properties
    @available_user_properties = extract_available_user_properties
  end

  def retention
    @from = Date.parse(params[:from] || 8.weeks.ago.beginning_of_week(:monday).to_s)
    @to = Date.parse(params[:to] || Date.current.to_s)
    @current_time_range = @from.beginning_of_day..@to.end_of_day
    @chart_dates = (@from..@to).map(&:to_s)
    @granularity = params[:granularity] || "weekly"

    @filter_prop_key = params[:filter_prop_key].presence
    @filter_prop_value = params[:filter_prop_value].presence

    @segment_id = params[:segment_id].presence
    @segments = @project.segments.order(:name)

    @saved_retentions = @project.saved_reports.by_type("retention").recent

    if @granularity == "daily"
      build_daily_retention
    else
      build_weekly_retention
    end

    compute_average_retention

    @available_user_properties = extract_available_user_properties
  end

  def errors
    @from = Date.parse(params[:from] || 7.days.ago.to_date.to_s)
    @to = Date.parse(params[:to] || Date.current.to_s)
    range_days = (@to - @from).to_i + 1
    prev_from = @from - range_days.days
    prev_to = @from - 1.day

    current_time_range = @from.beginning_of_day..@to.end_of_day
    prev_time_range = prev_from.beginning_of_day..prev_to.end_of_day
    current_range = @from..@to

    all_error_events = [ "$error", "$promise_error", "$server_error", "$network_error" ]
    js_error_events = [ "$error", "$promise_error" ]
    server_error_events = [ "$server_error" ]
    network_error_events = [ "$network_error" ]

    @error_type = params[:error_type] || "all"
    filtered_events = case @error_type
    when "frontend" then js_error_events
    when "backend" then server_error_events
    when "network" then network_error_events
    else all_error_events
    end

    @total_errors = @project.events.where(name: all_error_events, occurred_at: current_time_range).count
    @prev_total_errors = @project.events.where(name: all_error_events, occurred_at: prev_time_range).count

    @js_errors = @project.events.where(name: js_error_events, occurred_at: current_time_range).count
    @prev_js_errors = @project.events.where(name: js_error_events, occurred_at: prev_time_range).count

    @server_errors = @project.events.where(name: server_error_events, occurred_at: current_time_range).count
    @prev_server_errors = @project.events.where(name: server_error_events, occurred_at: prev_time_range).count

    @network_errors = @project.events.where(name: network_error_events, occurred_at: current_time_range).count
    @prev_network_errors = @project.events.where(name: network_error_events, occurred_at: prev_time_range).count

    @tab_counts = {
      "all" => @total_errors,
      "frontend" => @js_errors,
      "backend" => @server_errors,
      "network" => @network_errors
    }

    current_rollups = @project.event_daily_rollups.where(date: current_range)
    @daily_errors = current_rollups
      .where(event_name: filtered_events)
      .group(:date).sum(:count)
    @chart_dates = (@from..@to).map(&:to_s)

    @error_groups = @project.events
      .where(name: filtered_events, occurred_at: current_time_range)
      .group(
        Arel.sql("COALESCE(properties->>'message', 'Unknown')"),
        Arel.sql("COALESCE(properties->>'error_type', '')"),
        Arel.sql("events.name")
      )
      .select(
        Arel.sql("COALESCE(properties->>'message', 'Unknown') as message"),
        Arel.sql("COALESCE(properties->>'error_type', '') as error_type"),
        Arel.sql("events.name as event_name"),
        Arel.sql("COUNT(*) as occurrences"),
        Arel.sql("COUNT(DISTINCT COALESCE(properties->>'anonymous_id', user_profile_id::text)) as affected_users"),
        Arel.sql("MIN(occurred_at) as first_seen"),
        Arel.sql("MAX(occurred_at) as last_seen"),
        Arel.sql("MODE() WITHIN GROUP (ORDER BY COALESCE(properties->>'path', properties->>'request_path')) as top_page")
      )
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(50)

    @errors_by_page = @project.events
      .where(name: filtered_events, occurred_at: current_time_range)
      .pluck(Arel.sql("COALESCE(properties->>'path', properties->>'request_path')"))
      .compact.reject(&:blank?)
      .tally
      .sort_by { |_, c| -c }
      .first(10)

    @errors_by_user = @project.events
      .where(name: filtered_events, occurred_at: current_time_range)
      .pluck(Arel.sql("COALESCE(properties->>'anonymous_id', user_profile_id::text)"))
      .compact
      .tally
      .sort_by { |_, c| -c }
      .first(10)

    @browser_breakdown = @project.events
      .where(name: filtered_events, occurred_at: current_time_range)
      .pluck(Arel.sql("properties->>'browser'"))
      .compact.reject(&:blank?)
      .tally
      .sort_by { |_, c| -c }
      .first(10)

    compute_error_business_impact(current_time_range)
  end

  def error_detail
    @from = Date.parse(params[:from] || 7.days.ago.to_date.to_s)
    @to = Date.parse(params[:to] || Date.current.to_s)
    current_time_range = @from.beginning_of_day..@to.end_of_day
    error_events = [ "$error", "$promise_error", "$server_error" ]

    @message = params[:message] || ""

    base = @project.events
      .where(name: error_events, occurred_at: current_time_range)
      .where("properties->>'message' = ?", @message)

    @occurrences = base.order(occurred_at: :desc).limit(50).includes(:user_profile)

    @affected_users_list = base
      .select("DISTINCT COALESCE(properties->>'anonymous_id', user_profile_id::text) as uid")
      .map(&:uid).compact

    @daily_timeline = base.group(Arel.sql("occurred_at::date")).count
    @chart_dates = (@from..@to).map(&:to_s)

    @latest_event = base.order(occurred_at: :desc).first

    @total_occurrences = base.count
    @first_seen = base.minimum(:occurred_at)
    @last_seen = base.maximum(:occurred_at)

    if @latest_event
      @error_category = case @latest_event.name
      when "$server_error" then "Server Error"
      when "$promise_error" then "Promise Error"
      else "JS Error"
      end

      props = @latest_event.properties || {}
      @source_file = props["source"].presence
      @source_line = props["line"].present? && props["line"].to_i > 0 ? props["line"] : nil
      @source_col = props["col"].present? && props["col"].to_i > 0 ? props["col"] : nil
      @error_type_name = props["error_type"].presence

      if @latest_event.name == "$server_error"
        @server_controller = props["controller"]
        @server_action = props["action"]
        @request_path = props["request_path"]
        @http_method = props["http_method"]
        @exception_class = props["exception_class"]
      end
    end

    @error_pages = base
      .pluck(Arel.sql("COALESCE(properties->>'path', properties->>'request_path')"))
      .compact.reject(&:blank?)
      .tally
      .sort_by { |_, c| -c }
      .first(5)

    @browser_breakdown = base
      .pluck(Arel.sql("properties->>'browser'"))
      .compact.reject(&:blank?)
      .tally
      .sort_by { |_, c| -c }
      .first(5)

    @os_breakdown = base
      .pluck(Arel.sql("properties->>'os'"))
      .compact.reject(&:blank?)
      .tally
      .sort_by { |_, c| -c }
      .first(5)

    compute_error_business_impact(current_time_range)
  end

  def users
    set_date_range
    @query = params[:q]
    @page = [ params[:page].to_i, 1 ].max
    per_page = 50

    base = @project.user_profiles.order(last_seen_at: :desc)

    if @query.present?
      sanitized = ActiveRecord::Base.sanitize_sql_like(@query)
      base = base.where("external_id ILIKE ? OR properties::text ILIKE ?", "%#{sanitized}%", "%#{sanitized}%")
    end

    if params[:segment_id].present?
      segment = @project.segments.find_by(id: params[:segment_id])
      base = base.where(id: segment.matching_user_ids) if segment
    end

    @segments = @project.segments.order(:name)

    @total_users = base.count
    @new_users_in_range = @project.user_profiles.where(first_seen_at: @current_time_range).count
    @active_users_in_range = @project.events
      .where(occurred_at: @current_time_range)
      .where.not(user_profile_id: nil)
      .select(:user_profile_id).distinct.count

    @total_pages = [ (@total_users.to_f / per_page).ceil, 1 ].max

    @users = base
      .select("user_profiles.*, (SELECT COUNT(*) FROM events WHERE events.user_profile_id = user_profiles.id) as events_count")
      .offset((@page - 1) * per_page)
      .limit(per_page)
  end

  def export_csv
    set_date_range
    export_type = params[:type] || "events"

    csv_data = case export_type
    when "events"
      export_events_csv
    when "users"
      export_users_csv
    when "funnel"
      export_funnel_csv
    when "retention"
      export_retention_csv
    else
      export_events_csv
    end

    send_data csv_data,
      filename: "#{@project.name.parameterize}-#{export_type}-#{@from}-#{@to}.csv",
      type: "text/csv; charset=utf-8",
      disposition: "attachment"
  end

  def user_paths
    set_date_range
    @start_event = params[:start_event].presence || "$pageview"
    @depth = [ params[:depth].to_i, 1 ].max
    @depth = [ @depth, 5 ].min

    @available_events = @project.event_daily_rollups
      .where.not(event_name: SYSTEM_EVENTS - [ "$pageview" ])
      .distinct.pluck(:event_name).sort

    @paths = compute_user_paths(@start_event, @depth)
    @total_sessions = @paths.values.sum
  end

  def forms
    set_date_range

    form_submits = @project.events
      .where(name: "$form_submit", occurred_at: @current_time_range)
      .pluck(Arel.sql("properties->>'selector'"), :occurred_at, Arel.sql("COALESCE(properties->>'anonymous_id', user_profile_id::text)"))

    form_selectors = form_submits.map(&:first).compact.uniq

    @selected_form = params[:form].presence
    @forms = []

    form_selectors.each do |selector|
      submissions = form_submits.select { |s| s[0] == selector }
      submit_sessions = submissions.map(&:third).compact.uniq
      submit_count = submit_sessions.size

      field_interactions = @project.events
        .where(name: [ "$input_change", "$field_time" ], occurred_at: @current_time_range)
        .where("properties->>'form_selector' = ? OR properties->>'selector' LIKE ?", selector, "#{selector}%")
        .pluck(Arel.sql("COALESCE(properties->>'anonymous_id', user_profile_id::text)"))
        .compact.uniq

      interact_count = (field_interactions | submit_sessions).size
      completion_rate = interact_count > 0 ? (submit_count.to_f / interact_count * 100).round(1) : 0
      abandonment_rate = (100 - completion_rate).round(1)

      field_times = @project.events
        .where(name: "$field_time", occurred_at: @current_time_range)
        .where("properties->>'form_selector' = ? OR properties->>'selector' LIKE ?", selector, "#{selector}%")
        .pluck(Arel.sql("(properties->>'duration_ms')::int"))
        .compact
      avg_time_ms = field_times.any? ? (field_times.sum.to_f / field_times.size).round : 0

      @forms << {
        selector: selector,
        submissions: submit_count,
        interactions: interact_count,
        completion_rate: completion_rate,
        abandonment_rate: abandonment_rate,
        avg_time_ms: avg_time_ms
      }
    end

    @forms.sort_by! { |f| -f[:submissions] }

    if @selected_form.present?
      build_form_detail(@selected_form)
    end

    @daily_submissions = @project.event_daily_rollups
      .where(event_name: "$form_submit", date: @from..@to)
      .group(:date).sum(:count)
  end

  def anomalies
    set_date_range
    @active_anomalies = @project.anomalies.active.recent
    @resolved_anomalies = @project.anomalies
      .where.not(resolved_at: nil)
      .where(detected_at: @current_time_range)
      .recent
      .limit(50)
    @all_anomalies = @active_anomalies + @resolved_anomalies
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def set_date_range
    @from = Date.parse(params[:from] || 7.days.ago.to_date.to_s)
    @to = Date.parse(params[:to] || Date.current.to_s)
    @current_time_range = @from.beginning_of_day..@to.end_of_day
    @chart_dates = (@from..@to).map(&:to_s)
  end

  def compute_funnel(steps, window = "unlimited")
    return [] if steps.size < 2

    window_seconds = case window
    when "1h" then 3600
    when "1d" then 86400
    when "7d" then 7 * 86400
    when "30d" then 30 * 86400
    else nil
    end

    segment_user_ids = nil
    if @segment_id.present?
      segment = @project.segments.find_by(id: @segment_id)
      segment_user_ids = segment&.matching_user_ids
    end

    first_step_events = @project.events
      .where(occurred_at: @current_time_range, name: steps.first)
      .where.not(user_profile_id: nil)

    first_step_events = apply_funnel_property_filter(first_step_events)

    first_step_events = first_step_events.where(user_profile_id: segment_user_ids) if segment_user_ids

    user_ids = first_step_events.distinct.pluck(:user_profile_id)

    user_first_timestamps = first_step_events
      .group(:user_profile_id)
      .minimum(:occurred_at)

    results = [ { name: steps.first, count: user_ids.size, step_pct: 100.0, total_pct: 100.0, dropoff: 0, median_time: nil } ]
    total_start = user_ids.size

    steps.each_cons(2).with_index do |(prev_step, curr_step), idx|
      break if user_ids.empty?

      if window_seconds
        qualifying_users = []
        step_times = []

        user_ids.each do |uid|
          first_ts = user_first_timestamps[uid]
          next unless first_ts
          deadline = first_ts + window_seconds.seconds

          curr_events = @project.events
            .where(name: curr_step, user_profile_id: uid, occurred_at: @current_time_range)
            .where("occurred_at > (SELECT MAX(e2.occurred_at) FROM events e2 WHERE e2.project_id = ? AND e2.user_profile_id = ? AND e2.name = ? AND e2.occurred_at BETWEEN ? AND ?)",
              @project.id, uid, prev_step, @current_time_range.first, @current_time_range.last)
            .where("occurred_at <= ?", deadline)

          curr_events = apply_funnel_property_filter(curr_events)

          if curr_events.exists?
            qualifying_users << uid
            curr_ts = curr_events.minimum(:occurred_at)
            step_times << (curr_ts - first_ts).to_i if curr_ts && first_ts
          end
        end

        user_ids = qualifying_users
      else
        step_query = @project.events
          .where(occurred_at: @current_time_range, name: curr_step, user_profile_id: user_ids)
          .where(
            "occurred_at > (SELECT MAX(e2.occurred_at) FROM events e2 WHERE e2.project_id = events.project_id AND e2.user_profile_id = events.user_profile_id AND e2.name = ? AND e2.occurred_at BETWEEN ? AND ?)",
            prev_step, @current_time_range.first, @current_time_range.last
          )

        step_query = apply_funnel_property_filter(step_query)
        user_ids = step_query.distinct.pluck(:user_profile_id)

        step_times = user_ids.filter_map do |uid|
          first_ts = user_first_timestamps[uid]
          curr_ts = @project.events
            .where(name: curr_step, user_profile_id: uid, occurred_at: @current_time_range)
            .minimum(:occurred_at)
          (curr_ts - first_ts).to_i if curr_ts && first_ts
        end
      end

      prev_count = results.last[:count]
      step_pct = prev_count > 0 ? (user_ids.size.to_f / prev_count * 100).round(1) : 0
      total_pct = total_start > 0 ? (user_ids.size.to_f / total_start * 100).round(1) : 0
      dropoff = prev_count - user_ids.size

      median_time = if step_times.any?
        sorted = step_times.sort
        mid = sorted.size / 2
        sorted.size.odd? ? sorted[mid] : ((sorted[mid - 1] + sorted[mid]) / 2.0).round
      end

      results << { name: curr_step, count: user_ids.size, step_pct: step_pct, total_pct: total_pct, dropoff: dropoff, median_time: median_time }
    end

    results
  end

  def apply_funnel_property_filter(scope)
    return scope unless @filter_prop_key.present? && @filter_prop_value.present?

    if @filter_prop_type == "user"
      user_ids = @project.user_profiles
        .where("properties->>? ILIKE ?", @filter_prop_key, "%#{@filter_prop_value}%")
        .pluck(:id)
      scope.where(user_profile_id: user_ids)
    else
      scope.where("properties->>? ILIKE ?", @filter_prop_key, "%#{@filter_prop_value}%")
    end
  end

  def build_weekly_retention
    num_weeks = ((@to - @from).to_i / 7.0).ceil + 1
    @weeks = num_weeks.times.map { |i| @from + i.weeks }
    @weeks = @weeks.select { |w| w <= @to }

    users_with_first_seen = @project.user_profiles
      .where(first_seen_at: @current_time_range)
    users_with_first_seen = apply_retention_filter(users_with_first_seen)
    users_with_first_seen = users_with_first_seen.pluck(:id, :first_seen_at)

    cohorts = {}
    users_with_first_seen.each do |uid, first_seen|
      week_start = first_seen.to_date.beginning_of_week(:monday)
      cohorts[week_start] ||= []
      cohorts[week_start] << uid
    end

    @retention_data = []
    cohorts.each do |cohort_week, user_ids|
      next if user_ids.empty?

      active_weeks_by_user = Event
        .where(project_id: @project.id, user_profile_id: user_ids)
        .where(occurred_at: cohort_week.beginning_of_day..@to.end_of_day)
        .where.not(name: SYSTEM_EVENTS)
        .group(:user_profile_id)
        .pluck(:user_profile_id, Arel.sql("ARRAY_AGG(DISTINCT DATE_TRUNC('week', occurred_at)::date)"))
        .to_h

      cohort_size = user_ids.size
      max_offset = ((@to - cohort_week).to_i / 7.0).floor
      retention = (0..max_offset).map do |offset|
        target_week = cohort_week + offset.weeks
        active_count = active_weeks_by_user.count { |_, weeks| weeks.include?(target_week) }
        pct = cohort_size > 0 ? (active_count.to_f / cohort_size * 100).round(1) : 0
        { offset: offset, pct: pct, count: active_count }
      end

      @retention_data << { week: cohort_week, cohort_size: cohort_size, retention: retention }
    end

    @retention_data.sort_by! { |d| d[:week] }
    @max_offsets = @retention_data.map { |d| d[:retention].size }.max || 0
    @offset_label = "Wk"
  end

  def build_daily_retention
    users_with_first_seen = @project.user_profiles
      .where(first_seen_at: @current_time_range)
    users_with_first_seen = apply_retention_filter(users_with_first_seen)
    users_with_first_seen = users_with_first_seen.pluck(:id, :first_seen_at)

    cohorts = {}
    users_with_first_seen.each do |uid, first_seen|
      day = first_seen.to_date
      cohorts[day] ||= []
      cohorts[day] << uid
    end

    max_days = [ (@to - @from).to_i, 30 ].min

    @retention_data = []
    cohorts.each do |cohort_day, user_ids|
      next if user_ids.empty?

      active_days_by_user = Event
        .where(project_id: @project.id, user_profile_id: user_ids)
        .where(occurred_at: cohort_day.beginning_of_day..@to.end_of_day)
        .where.not(name: SYSTEM_EVENTS)
        .group(:user_profile_id)
        .pluck(:user_profile_id, Arel.sql("ARRAY_AGG(DISTINCT occurred_at::date)"))
        .to_h

      cohort_size = user_ids.size
      max_offset = [ (@to - cohort_day).to_i, max_days ].min
      retention = (0..max_offset).map do |offset|
        target_day = cohort_day + offset.days
        active_count = active_days_by_user.count { |_, days| days.include?(target_day) }
        pct = cohort_size > 0 ? (active_count.to_f / cohort_size * 100).round(1) : 0
        { offset: offset, pct: pct, count: active_count }
      end

      @retention_data << { week: cohort_day, cohort_size: cohort_size, retention: retention }
    end

    @retention_data.sort_by! { |d| d[:week] }
    @max_offsets = [ @retention_data.map { |d| d[:retention].size }.max || 0, max_days + 1 ].min
    @offset_label = "Day"
  end

  def apply_retention_filter(scope)
    if @segment_id.present?
      segment = @project.segments.find_by(id: @segment_id)
      scope = scope.where(id: segment.matching_user_ids) if segment
    end

    if @filter_prop_key.present? && @filter_prop_value.present?
      scope = scope.where("properties->>? ILIKE ?", @filter_prop_key, "%#{@filter_prop_value}%")
    end

    scope
  end

  def compute_average_retention
    return @avg_retention = [] if @retention_data.empty?

    @avg_retention = @max_offsets.times.map do |i|
      values = @retention_data.filter_map { |d| d[:retention][i]&.fetch(:pct) }
      values.any? ? (values.sum / values.size.to_f).round(1) : nil
    end
  end

  def build_user_sessions(user)
    session_starts = user.events
      .where(name: "$session_start", occurred_at: @current_time_range)
      .order(occurred_at: :desc)
      .limit(5)

    session_starts.map do |start_event|
      end_event = user.events
        .where(name: "$session_end")
        .where("occurred_at > ?", start_event.occurred_at)
        .order(:occurred_at)
        .first

      duration = if end_event
        end_event.properties["duration_seconds"]&.to_i
      end

      pages_viewed = end_event&.properties&.dig("pages_viewed")&.to_i

      events = user.events
        .where(occurred_at: start_event.occurred_at..(end_event&.occurred_at || start_event.occurred_at + 30.minutes))
        .where.not(name: SYSTEM_EVENTS)
        .order(:occurred_at)
        .limit(20)

      {
        started_at: start_event.occurred_at,
        duration: duration,
        pages_viewed: pages_viewed,
        events_count: events.size,
        events: events
      }
    end
  end

  def group_events_by_session(events)
    groups = []
    current_session = nil

    events.each do |event|
      if event.name == "$session_start"
        current_session = { start: event, events: [] }
        groups << { type: :session, session: current_session }
      elsif event.name == "$session_end" && current_session
        current_session[:end] = event
        current_session = nil
      elsif current_session
        current_session[:events] << event
      else
        groups << { type: :event, event: event }
      end
    end

    groups
  end

  def extract_available_properties
    @project.events
      .where(occurred_at: @current_time_range)
      .where.not(name: SYSTEM_EVENTS)
      .limit(200)
      .pluck(:properties)
      .flat_map(&:keys)
      .reject { |k| k == "anonymous_id" }
      .tally
      .sort_by { |_, c| -c }
      .first(20)
      .map(&:first)
  end

  def extract_available_user_properties
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

  def compute_user_paths(start_event, depth)
    session_starts = @project.events
      .where(name: "$session_start", occurred_at: @current_time_range)
      .where.not(user_profile_id: nil)
      .order(:occurred_at)
      .limit(1000)
      .pluck(:user_profile_id, :occurred_at)

    paths = Hash.new(0)

    session_starts.each do |user_profile_id, started_at|
      session_events = @project.events
        .where(user_profile_id: user_profile_id)
        .where(occurred_at: started_at..(started_at + 30.minutes))
        .where.not(name: SYSTEM_EVENTS - [ "$pageview" ])
        .order(:occurred_at)
        .limit(depth + 1)
        .pluck(:name, Arel.sql("COALESCE(properties->>'path', name)"))

      next if session_events.size < 2

      path_key = session_events.first(depth + 1).map(&:last).join(" → ")
      paths[path_key] += 1
    end

    paths.sort_by { |_, count| -count }.first(20).to_h
  end

  def export_events_csv
    events = @project.events
      .where(occurred_at: @current_time_range)
      .order(occurred_at: :desc)
      .limit(10_000)
      .includes(:user_profile)

    CSV.generate do |csv|
      csv << [ "Event", "User", "Timestamp", "Properties" ]
      events.each do |event|
        csv << [
          event.name,
          event.user_profile&.external_id || "anonymous",
          event.occurred_at.iso8601,
          event.properties.except("anonymous_id").to_json
        ]
      end
    end
  end

  def export_users_csv
    users = @project.user_profiles.order(last_seen_at: :desc).limit(10_000)

    CSV.generate do |csv|
      csv << [ "External ID", "First Seen", "Last Seen", "Properties" ]
      users.each do |user|
        csv << [
          user.external_id,
          user.first_seen_at&.iso8601,
          user.last_seen_at&.iso8601,
          user.properties.to_json
        ]
      end
    end
  end

  def export_funnel_csv
    @steps = Array(params[:steps]).reject(&:blank?).first(10)
    @window = params[:window] || "unlimited"
    @filter_prop_key = params[:filter_prop_key].presence
    @filter_prop_value = params[:filter_prop_value].presence
    @filter_prop_type = params[:filter_prop_type] || "event"
    @segment_id = params[:segment_id].presence

    results = compute_funnel(@steps, @window)

    CSV.generate do |csv|
      csv << [ "Step", "Users", "Step Conversion %", "Overall Conversion %", "Drop-off", "Median Time (s)" ]
      results.each do |step|
        csv << [ step[:name], step[:count], step[:step_pct], step[:total_pct], step[:dropoff], step[:median_time] ]
      end
    end
  end

  def export_retention_csv
    @granularity = params[:granularity] || "weekly"
    @filter_prop_key = params[:filter_prop_key].presence
    @filter_prop_value = params[:filter_prop_value].presence
    @segment_id = params[:segment_id].presence

    if @granularity == "daily"
      build_daily_retention
    else
      build_weekly_retention
    end

    CSV.generate do |csv|
      headers = [ "Cohort", "Users" ] + @max_offsets.times.map { |i| "#{@offset_label} #{i}" }
      csv << headers
      @retention_data.each do |row|
        values = [ row[:week].strftime("%Y-%m-%d"), row[:cohort_size] ]
        @max_offsets.times do |i|
          cell = row[:retention][i]
          values << (cell ? "#{cell[:pct]}%" : "")
        end
        csv << values
      end
    end
  end

  def build_form_detail(selector)
    field_events = @project.events
      .where(name: [ "$input_change", "$field_time" ], occurred_at: @current_time_range)
      .where("properties->>'form_selector' = ? OR properties->>'selector' LIKE ?", selector, "#{selector}%")

    field_sessions = field_events
      .pluck(
        Arel.sql("COALESCE(properties->>'field_name', properties->>'name', 'unknown')"),
        Arel.sql("COALESCE(properties->>'anonymous_id', user_profile_id::text)")
      )

    field_counts = {}
    field_sessions.each do |field, session_id|
      next if session_id.blank?
      field_counts[field] ||= Set.new
      field_counts[field] << session_id
    end

    submit_sessions = @project.events
      .where(name: "$form_submit", occurred_at: @current_time_range)
      .where("properties->>'selector' = ?", selector)
      .pluck(Arel.sql("COALESCE(properties->>'anonymous_id', user_profile_id::text)"))
      .compact.uniq

    total_starters = field_counts.values.map(&:size).max || 0

    @field_funnel = field_counts
      .map { |field, sessions| { field: field, sessions: sessions.size } }
      .sort_by { |f| -f[:sessions] }

    @field_funnel << { field: "Submit", sessions: submit_sessions.size }

    @field_times = @project.events
      .where(name: "$field_time", occurred_at: @current_time_range)
      .where("properties->>'form_selector' = ? OR properties->>'selector' LIKE ?", selector, "#{selector}%")
      .group(Arel.sql("COALESCE(properties->>'field_name', properties->>'name', 'unknown')"))
      .pluck(
        Arel.sql("COALESCE(properties->>'field_name', properties->>'name', 'unknown')"),
        Arel.sql("AVG((properties->>'duration_ms')::int)"),
        Arel.sql("COUNT(*)")
      )
      .map { |f, avg, cnt| { field: f, avg_ms: avg&.round || 0, count: cnt } }
      .sort_by { |f| -f[:avg_ms] }

    page_paths = @project.events
      .where(name: "$form_submit", occurred_at: @current_time_range)
      .where("properties->>'selector' = ?", selector)
      .pluck(Arel.sql("DISTINCT properties->>'path'"))
      .compact

    @frustration_events = []
    if page_paths.any?
      @frustration_events = @project.events
        .where(name: [ "$rage_click", "$dead_click" ], occurred_at: @current_time_range)
        .where("properties->>'path' IN (?)", page_paths)
        .group(:name)
        .count
    end
  end

  def compute_error_business_impact(current_time_range)
    all_error_events = [ "$error", "$promise_error", "$server_error", "$network_error" ]
    conversion_event = @project.conversion_event.presence || "purchase"

    error_user_ids = @project.events
      .where(name: all_error_events, occurred_at: current_time_range)
      .where.not(user_profile_id: nil)
      .distinct.pluck(:user_profile_id)

    all_active_user_ids = @project.events
      .where(occurred_at: current_time_range)
      .where.not(user_profile_id: nil)
      .distinct.pluck(:user_profile_id)

    clean_user_ids = all_active_user_ids - error_user_ids

    @impact = { error_users: error_user_ids.size, clean_users: clean_user_ids.size, conversion_event: conversion_event }

    if error_user_ids.any?
      error_converts = @project.events
        .where(name: conversion_event, user_profile_id: error_user_ids, occurred_at: current_time_range)
        .distinct.count(:user_profile_id)
      @impact[:error_conversion_rate] = (error_converts.to_f / error_user_ids.size * 100).round(1)
      @impact[:error_converts] = error_converts
    else
      @impact[:error_conversion_rate] = 0
      @impact[:error_converts] = 0
    end

    if clean_user_ids.any?
      clean_converts = @project.events
        .where(name: conversion_event, user_profile_id: clean_user_ids, occurred_at: current_time_range)
        .distinct.count(:user_profile_id)
      @impact[:clean_conversion_rate] = (clean_converts.to_f / clean_user_ids.size * 100).round(1)
      @impact[:clean_converts] = clean_converts
    else
      @impact[:clean_conversion_rate] = 0
      @impact[:clean_converts] = 0
    end

    rate_diff = @impact[:clean_conversion_rate] - @impact[:error_conversion_rate]
    @impact[:lost_conversions] = rate_diff > 0 ? (rate_diff / 100 * error_user_ids.size).round : 0
    @impact[:lost_revenue] = if @project.avg_conversion_value.present? && @impact[:lost_conversions] > 0
      (@impact[:lost_conversions] * @project.avg_conversion_value).round(2)
    end
  end

  def project_params
    params.require(:project).permit(:name, :url, :conversion_event, :avg_conversion_value, :retention_days)
  end
end
