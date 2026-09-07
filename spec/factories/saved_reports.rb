FactoryBot.define do
  factory :saved_report do
    project
    name { "My Report" }
    report_type { "funnel" }
    configuration { { "steps" => [ "signup", "purchase" ], "window" => "7d" } }
  end
end
