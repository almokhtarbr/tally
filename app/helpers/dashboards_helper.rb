module DashboardsHelper
  # A minimal inline SVG sparkline for a widget's daily series. No JS, no
  # library — just a normalised polyline. Returns nil for an empty or
  # all-zero series so the caller can skip it.
  def sparkline(series, width: 132, height: 30, color: "#5046e5")
    values = Array(series).map(&:to_i)
    return if values.length < 2 || values.max.zero?

    max = values.max.to_f
    step = width.to_f / (values.length - 1)
    points = values.each_with_index.map do |v, i|
      x = (i * step).round(2)
      y = (height - (v / max) * (height - 2) - 1).round(2)
      "#{x},#{y}"
    end.join(" ")

    content_tag(:svg, class: "block mt-2", width: width, height: height,
      viewBox: "0 0 #{width} #{height}", preserveAspectRatio: "none",
      xmlns: "http://www.w3.org/2000/svg") do
      tag.polyline(points: points, fill: "none", stroke: color,
        "stroke-width": "1.5", "stroke-linejoin": "round", "stroke-linecap": "round")
    end
  end
end
