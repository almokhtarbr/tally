FactoryBot.define do
  factory :dashboard do
    project
    name { "Growth" }
  end

  factory :dashboard_widget do
    dashboard
    saved_report { association :saved_report, project: dashboard.project }
    position { 0 }
  end
end
