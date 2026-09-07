# The numbers for one project's weekly email digest: totals for the last 7
# days, the same window a week earlier for comparison, the top events, and new
# users. Reads the pre-aggregated rollups where it can and the events table
# for the rest.
class ProjectDigest
  Change = Struct.new(:current, :previous) do
    def delta = current - previous
    def pct
      return nil if previous.zero?
      ((current - previous) * 100.0 / previous).round
    end
  end

  def initialize(project, ending: Date.current)
    @project = project
    @to    = ending
    @from  = ending - 7
    @prev_to   = @from
    @prev_from = @from - 7
  end

  attr_reader :project, :from, :to

  def events
    Change.new(rollup_count(@from, @to), rollup_count(@prev_from, @prev_to))
  end

  def active_users
    Change.new(unique_users(@from, @to), unique_users(@prev_from, @prev_to))
  end

  def new_users
    project.user_profiles.where(created_at: window(@from, @to)).count
  end

  # [["signup", 42], ["page_view", 30], ...]
  def top_events(limit = 5)
    project.event_daily_rollups
           .where(date: @from...@to)
           .group(:event_name)
           .order(Arel.sql("SUM(count) DESC"))
           .limit(limit)
           .sum(:count)
           .to_a
  end

  def anomalies
    project.anomalies.where(detected_at: window(@from, @to)).order(detected_at: :desc)
  end

  def any_activity?
    events.current.positive?
  end

  private

  def window(from, to) = from.beginning_of_day...to.beginning_of_day

  def rollup_count(from, to)
    project.event_daily_rollups.where(date: from...to).sum(:count)
  end

  def unique_users(from, to)
    project.events.where(occurred_at: window(from, to)).distinct.count(:user_profile_id)
  end
end
