require "json"
require "net/http"
require "uri"

module Watchtower
  # Pushes a build's source maps to Watchtower so JS stack frames get
  # de-minified at ingest. The server endpoint has always existed; this is
  # the half that runs in your build.
  #
  #   Watchtower::SourceMaps.upload!(dir: "public/assets", release: "abc1234")
  #
  # or from a build script / CI step:
  #
  #   bundle exec rake watchtower:sourcemaps
  #   bundle exec rake "watchtower:sourcemaps[public/assets,abc1234]"
  #
  # Uploads every *.map under `dir` (recursively), in batches, to
  # POST /api/:key/artifacts. Returns a summary hash. Raises only on
  # misconfiguration — a failed HTTP call is reported in the summary so a
  # deploy is never blocked by the error tracker.
  module SourceMaps
    MAX_BYTES  = 5 * 1024 * 1024
    BATCH      = 10
    TIMEOUT    = 30

    Result = Struct.new(:uploaded, :skipped, :failed, :errors, keyword_init: true) do
      def to_s
        "uploaded #{uploaded}, skipped #{skipped}, failed #{failed}" +
          (errors.empty? ? "" : " — #{errors.join('; ')}")
      end
    end

    class << self
      def upload!(dir: default_dir, release: nil, config: Watchtower.config, io: $stdout)
        release = (release || config.release).to_s
        raise ArgumentError, "WATCHTOWER_URL and WATCHTOWER_PUBLIC_KEY must be set" if
          config.url.to_s.empty? || config.public_key.to_s.empty?
        raise ArgumentError, "a release is required (WATCHTOWER_RELEASE or pass release:)" if release.empty?

        maps = Dir.glob(File.join(dir, "**", "*.map")).sort
        io&.puts("[watchtower] #{maps.size} map(s) under #{dir} -> release #{release}")

        result = Result.new(uploaded: 0, skipped: 0, failed: 0, errors: [])
        maps.each_slice(BATCH) { |batch| push(batch, release, config, result, io) }
        io&.puts("[watchtower] #{result}")
        result
      end

      # Where a Rails/Propshaft build leaves its assets.
      def default_dir
        ENV["WATCHTOWER_SOURCEMAP_DIR"].to_s.empty? ? "public/assets" : ENV["WATCHTOWER_SOURCEMAP_DIR"]
      end

      private

      def push(paths, release, config, result, io)
        artifacts = paths.filter_map do |path|
          size = File.size(path)
          if size > MAX_BYTES
            result.skipped += 1
            io&.puts("[watchtower]   skip #{File.basename(path)} (#{size} bytes > #{MAX_BYTES})")
            next
          end
          { name: File.basename(path), content: File.read(path) }
        end
        return if artifacts.empty?

        code, body = post(config, release, artifacts)
        if code == 202
          accepted = (JSON.parse(body)["accepted"] rescue artifacts.size)
          result.uploaded += accepted.to_i
          result.failed   += artifacts.size - accepted.to_i
        else
          result.failed += artifacts.size
          result.errors << "HTTP #{code}: #{body.to_s[0, 200]}"
        end
      rescue StandardError => e
        result.failed += paths.size
        result.errors << "#{e.class}: #{e.message}"
      end

      def post(config, release, artifacts)
        uri = URI("#{config.url.to_s.sub(%r{/+\z}, '')}/api/#{config.public_key}/artifacts")
        req = Net::HTTP::Post.new(uri)
        req["Content-Type"] = "application/json"
        req["User-Agent"]   = "watchtower-ruby"
        req.body = JSON.generate(release: release, artifacts: artifacts)
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                              open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |h| h.request(req) }
        [ res.code.to_i, res.body ]
      end
    end
  end
end
