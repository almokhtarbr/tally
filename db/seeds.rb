puts "Creating demo project..."
project = Project.find_or_create_by!(name: "Demo App") do |p|
  p.url = "https://demo.example.com"
end

puts "  API Key:    #{project.api_key}"
puts "  API Secret: #{project.api_secret}"

puts "Creating demo users..."
users = 20.times.map do |i|
  EventIngestionService.identify(
    project: project,
    user_id: "user#{i + 1}@example.com",
    properties: {
      name: "User #{i + 1}",
      plan: %w[free starter premium enterprise].sample,
      company: "Company #{('A'..'T').to_a[i]}",
      role: %w[admin member viewer].sample
    }
  )
end

event_types = [
  { name: "signup", weight: 5 },
  { name: "login", weight: 30 },
  { name: "project-created", weight: 15 },
  { name: "item-created", weight: 20 },
  { name: "invoice-sent", weight: 10 },
  { name: "subscription-update", weight: 5 },
  { name: "export-pdf", weight: 8 },
  { name: "search", weight: 25 },
  { name: "settings-changed", weight: 3 },
  { name: "user-invited", weight: 4 }
]

puts "Generating 1000 events over 30 days..."
1000.times do
  event = event_types.sample
  user = users.sample
  days_ago = rand(0..29)
  hours_ago = rand(0..23)

  EventIngestionService.track(
    project: project,
    event_name: event[:name],
    user_id: user.external_id,
    properties: {
      source: %w[web mobile api].sample,
      version: "1.#{rand(0..9)}.#{rand(0..20)}"
    },
    timestamp: days_ago.days.ago + hours_ago.hours
  )
end

puts "Done! #{project.events_count} events created for #{project.user_profiles.count} users."
puts ""
puts "Start the server and visit http://localhost:3000"
