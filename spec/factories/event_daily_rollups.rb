FactoryBot.define do
  factory :event_daily_rollup do
    project
    event_name { "test_event" }
    date { Date.current }
    count { 1 }
  end
end
