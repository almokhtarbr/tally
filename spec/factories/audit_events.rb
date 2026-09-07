FactoryBot.define do
  factory :audit_event do
    project
    user
    action { "project.update" }
    summary { "Updated name" }
    metadata { {} }
  end
end
