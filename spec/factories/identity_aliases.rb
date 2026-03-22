FactoryBot.define do
  factory :identity_alias do
    project
    user_profile
    sequence(:anonymous_id) { |n| "anon_#{n}" }
  end
end
