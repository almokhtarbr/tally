module Watchtower
  # Turns an exception's backtrace into structured frames the ingest API wants:
  #   { filename:, abs_path:, lineno:, function:, in_app:,
  #     context_line:, pre_context: [...], post_context: [...] }
  # Source context (±CONTEXT_LINES) is attached for in-app frames whose file is
  # readable, the way Sentry/Rollbar show the failing line in situ.
  module Backtrace
    MAX_FRAMES = 100
    CONTEXT_LINES = 5
    MAX_SOURCE_FRAMES = 12       # don't read a file for every gem frame
    # "app/models/deploy.rb:42:in `run'"  and  "...:in 'run'"  (Ruby 3.4+)
    LINE_RE = /\A(?<file>.+?):(?<line>\d+):in [`'](?<method>.+)'\z/
    NON_APP = %r{(/gems/|/ruby/\d|/vendor/bundle/|<internal:)}

    module_function

    def extract(exception, root:)
      locations = exception.backtrace_locations
      frames =
        if locations
          locations.first(MAX_FRAMES).map { |loc| from_location(loc, root) }
        else
          Array(exception.backtrace).first(MAX_FRAMES).filter_map { |l| from_string(l, root) }
        end
      attach_source(frames)
      frames
    rescue StandardError
      []
    end

    def from_location(loc, root)
      path = loc.absolute_path || loc.path.to_s
      {
        filename: relativize(path, root),
        abs_path: path,
        lineno:   loc.lineno,
        function: loc.label.to_s,
        in_app:   in_app?(path, root),
      }
    end

    def from_string(line, root)
      m = LINE_RE.match(line.to_s.strip) or return nil
      {
        filename: relativize(m[:file], root),
        abs_path: m[:file],
        lineno:   m[:line].to_i,
        function: m[:method],
        in_app:   in_app?(m[:file], root),
      }
    end

    def attach_source(frames)
      budget = MAX_SOURCE_FRAMES
      frames.each do |f|
        next unless f[:in_app] && budget.positive?
        lines = read_lines(f[:abs_path]) or next
        budget -= 1
        i = f[:lineno] - 1
        next if i.negative? || i >= lines.length
        f[:context_line] = lines[i]&.rstrip
        f[:pre_context]  = lines[[ i - CONTEXT_LINES, 0 ].max...i].map(&:rstrip)
        f[:post_context] = lines[(i + 1)..(i + CONTEXT_LINES)].to_a.map(&:rstrip)
      end
    rescue StandardError
      nil
    ensure
      frames.each { |f| f.delete(:abs_path) }
    end

    def read_lines(path)
      return nil if path.blank? || path.start_with?("(") || path.start_with?("<")
      return nil unless File.file?(path) && File.size(path) < 512_000
      (@cache ||= {})[path] ||= File.readlines(path, chomp: false)
    rescue SystemCallError
      nil
    end

    def relativize(path, root)
      root = root.to_s
      return path.sub("#{root}/", "") if root.present? && path.start_with?("#{root}/")
      if (i = path.index("/gems/"))
        return path[(i + 1)..]
      end
      path
    end

    def in_app?(path, root)
      root = root.to_s
      path.start_with?("#{root}/") && !path.match?(NON_APP)
    end
  end
end
