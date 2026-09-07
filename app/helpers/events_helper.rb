module EventsHelper
  EVENT_COLORS = {
    "$pageview" => "bg-[#5046e5]/10 text-[#5046e5]",
    "$click" => "bg-[#0ea5e9]/10 text-[#0ea5e9]",
    "$rage_click" => "bg-[#ef4444]/10 text-[#ef4444]",
    "$dead_click" => "bg-[#f59e0b]/10 text-[#f59e0b]",
    "$form_submit" => "bg-[#14b8a6]/10 text-[#14b8a6]",
    "$input_change" => "bg-[#8b8ba3]/10 text-[#8b8ba3]",
    "$scroll_depth" => "bg-[#8b8ba3]/10 text-[#8b8ba3]",
    "$page_leave" => "bg-[#8b8ba3]/10 text-[#8b8ba3]",
    "$session_start" => "bg-[#22c55e]/10 text-[#22c55e]",
    "$session_end" => "bg-[#8b8ba3]/10 text-[#8b8ba3]",
    "$error" => "bg-[#ef4444]/10 text-[#ef4444]",
    "$promise_error" => "bg-[#ef4444]/10 text-[#ef4444]",
    "$outbound_click" => "bg-[#a78bfa]/10 text-[#a78bfa]",
    "$copy" => "bg-[#8b8ba3]/10 text-[#8b8ba3]",
    "$network_error" => "bg-[#f59e0b]/10 text-[#f59e0b]",
    "$server_error" => "bg-[#f97316]/10 text-[#f97316]",
    "$resize" => "bg-[#8b8ba3]/10 text-[#8b8ba3]",
    "$field_time" => "bg-[#8b8ba3]/10 text-[#8b8ba3]"
  }.freeze

  def event_badge_class(name)
    EVENT_COLORS[name] || "bg-[#a78bfa]/10 text-[#a78bfa]"
  end

  def event_badge(name)
    label = name.sub("$", "")
    tag.span(label, class: "inline-flex rounded-md px-2 py-[2px] text-[11px] font-medium #{event_badge_class(name)}")
  end

  def format_duration(seconds)
    return "—" unless seconds && seconds > 0
    days = seconds / 86400
    hours = (seconds % 86400) / 3600
    mins = (seconds % 3600) / 60
    secs = seconds % 60

    if days > 0
      "#{days}d #{hours}h"
    elsif hours > 0
      "#{hours}h #{mins}m"
    elsif mins > 0
      "#{mins}m #{secs}s"
    else
      "#{secs}s"
    end
  end
end
