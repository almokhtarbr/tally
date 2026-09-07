FactoryBot.define do
  factory :webhook do
    project
    url { "https://example.com/webhook" }
    event_names { [ "*" ] }
  end
end
