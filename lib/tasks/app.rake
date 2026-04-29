namespace :app do
  desc "Run db/seeds.rb (workaround for Kernel#load failing on Cyrillic paths on Windows)"
  task seed: :environment do
    seeds_path = Rails.root.join("db", "seeds.rb")
    abort "seeds.rb not found at #{seeds_path}" unless File.exist?(seeds_path)
    eval(File.read(seeds_path), TOPLEVEL_BINDING, "db/seeds.rb")
  end
end
