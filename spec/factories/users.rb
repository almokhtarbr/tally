FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    password { "password123" }
    password_confirmation { password }
    role { "admin" }
    invitation_accepted_at { Time.current }

    trait :invited do
      invitation_accepted_at { nil }
    end
  end
end
