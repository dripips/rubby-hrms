# Bullet — детектор N+1 / unused-eager-load / counter_cache.
#
# В dev: алёрт в логе + Rails footer panel.
# В test: бросает ошибку (CI ломается на N+1) — пока выключено,
# включим точечно после ручного аудита, иначе текущий smoke spec
# с полным seed и неоптимизированными вьюхами завалит весь CI.
return unless defined?(Bullet)

Rails.application.config.after_initialize do
  Bullet.enable        = true
  Bullet.alert         = false
  Bullet.bullet_logger = true
  Bullet.console       = false
  Bullet.rails_logger  = true
  Bullet.add_footer    = Rails.env.development?
  # Bullet.raise        = Rails.env.test?  # включим в v1.11 после фикса baseline

  # Игнорируем известные false-positives — добавлять сюда после ручной проверки.
  Bullet.add_safelist type: :n_plus_one_query, class_name: "Notification", association: :event
end
