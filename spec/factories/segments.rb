FactoryBot.define do
  factory :segment do
    project
    name { "Power Users" }
    conditions { [{ "type" => "event", "event" => "purchase", "operator" => "did", "days" => 30 }] }
  end
end
