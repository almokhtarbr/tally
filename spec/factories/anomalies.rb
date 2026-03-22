FactoryBot.define do
  factory :anomaly do
    project
    event_name { "signup" }
    anomaly_type { "drop" }
    expected_value { 45.0 }
    actual_value { 17.0 }
    z_score { -3.2 }
    severity { "warning" }
    detected_at { Time.current }
  end
end
