Rails.application.config.dartsass.builds = {
  "application.scss" => "application.css"
}

design_system_path = Rails.root.join("vendor", "design-system").to_s.tr("\\", "/")
bootstrap_spec     = Gem.loaded_specs["bootstrap"]
bootstrap_path     = "#{bootstrap_spec.full_gem_path}/assets/stylesheets".tr("\\", "/")

Rails.application.config.dartsass.build_options << "--load-path=#{design_system_path}"
Rails.application.config.dartsass.build_options << "--load-path=#{bootstrap_path}"
