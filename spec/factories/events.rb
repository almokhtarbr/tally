FactoryBot.define do
  factory :event do
    project
    name { "test_event" }
    occurred_at { Time.current }
    properties { {} }

    trait :with_user do
      user_profile
    end

    trait :pageview do
      name { "$pageview" }
      properties { { "path" => "/home" } }
    end

    trait :session_start do
      name { "$session_start" }
      properties { { "browser" => "Chrome", "os" => "macOS" } }
    end

    trait :session_end do
      name { "$session_end" }
      properties { { "duration_seconds" => 120, "pages_viewed" => 3 } }
    end

    trait :error do
      name { "$error" }
      properties { { "message" => "Uncaught TypeError", "source" => "app.js", "line" => "42" } }
    end
  end
end
