class Segment < ApplicationRecord
  belongs_to :project

  validates :name, presence: true, uniqueness: { scope: :project_id }
  validates :conditions, presence: true

  before_validation :strip_empty_conditions

  def matching_user_ids
    scope = project.user_profiles

    conditions.each do |condition|
      scope = apply_condition(scope, condition)
    end

    scope.pluck(:id)
  end

  def matching_users
    project.user_profiles.where(id: matching_user_ids)
  end

  def user_count
    matching_user_ids.size
  end

  private

  def apply_condition(scope, condition)
    case condition["type"]
    when "event"
      apply_event_condition(scope, condition)
    when "property"
      apply_property_condition(scope, condition)
    else
      scope
    end
  end

  def apply_event_condition(scope, condition)
    event_name = condition["event"]
    operator = condition["operator"]
    days = condition["days"]&.to_i

    time_constraint = days ? days.days.ago : nil

    event_query = Event.where(project_id: project_id, name: event_name)
    event_query = event_query.where("occurred_at >= ?", time_constraint) if time_constraint

    case operator
    when "did"
      scope.where(id: event_query.select(:user_profile_id).where.not(user_profile_id: nil))
    when "did_not"
      scope.where.not(id: event_query.select(:user_profile_id).where.not(user_profile_id: nil))
    when "did_at_least"
      count = condition["count"]&.to_i || 1
      user_ids = event_query.where.not(user_profile_id: nil)
        .group(:user_profile_id).having("COUNT(*) >= ?", count)
        .pluck(:user_profile_id)
      scope.where(id: user_ids)
    else
      scope
    end
  end

  def apply_property_condition(scope, condition)
    key = condition["key"]
    operator = condition["operator"]
    value = condition["value"]

    case operator
    when "equals"
      scope.where("properties->>? = ?", key, value)
    when "not_equals"
      scope.where("properties->>? != ? OR properties->>? IS NULL", key, value, key)
    when "contains"
      scope.where("properties->>? ILIKE ?", key, "%#{sanitize_like(value)}%")
    when "is_set"
      scope.where("properties->>? IS NOT NULL", key)
    when "is_not_set"
      scope.where("properties->>? IS NULL", key)
    else
      scope
    end
  end

  def sanitize_like(value)
    value.to_s.gsub(/[%_\\]/) { |m| "\\#{m}" }
  end

  def strip_empty_conditions
    self.conditions = conditions.reject { |c| c["type"].blank? } if conditions.is_a?(Array)
  end
end
