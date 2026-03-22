FactoryBot.define do
  factory :project_membership do
    user
    project
    role { "editor" }
  end
end
