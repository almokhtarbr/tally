namespace :watchtower do
  desc "Upload this build's JS source maps to Watchtower (args: dir, release)"
  task :sourcemaps, [ :dir, :release ] => :environment do |_t, args|
    require "watchtower/source_maps"
    Watchtower::SourceMaps.upload!(
      dir:     args[:dir].presence || Watchtower::SourceMaps.default_dir,
      release: args[:release].presence
    )
  end
end
