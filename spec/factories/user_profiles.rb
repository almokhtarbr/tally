FactoryBot.define do
  factory :user_profile do
    project
    sequence(:external_id) { |n| "user_#{n}@example.com" }
    first_seen_at { 1.week.ago }
    last_seen_at { Time.current }
  end
end
