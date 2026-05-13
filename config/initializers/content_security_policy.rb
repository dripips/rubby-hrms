# Content Security Policy (CSP) — защита от XSS / data-injection.
#
# v1.11 — включаем в **report-only** режиме в production. Это значит:
#   • Браузер не блокирует ничего, но шлёт POST на /csp_violations при
#     несоблюдении политики.
#   • Мы наблюдаем 1-2 недели, фиксим все false-positive, потом снимаем
#     report_only и включаем enforce.
#
# В dev / test ничего не делаем — оставляем как есть, чтобы не мешать
# рабочему процессу с локальными ассетами и live-reload'ом.
#
# Источники, которые мы реально используем (см. layouts/application.html.erb):
#   • cdn.jsdelivr.net — FullCalendar, Swagger UI, Bootstrap JS, Prism syntax
#   • fonts.googleapis.com / fonts.gstatic.com — Inter font
#   • mc.webvisor.org / mc.yandex.ru — Yandex.Metrika (на лендинге)
#   • api.telegram.org — наш Telegram webhook setup (server-side, не browser)
#
# 'unsafe-inline' на style/script-src оставим пока — Stimulus + Bootstrap
# инлайнят атрибуты + есть legacy <style style="..."> в few view. Через релиз
# (v1.12) уберём через nonce-based CSP.

return unless Rails.env.production?

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.base_uri    :self
    policy.font_src    :self, :https, :data,
                       "https://fonts.gstatic.com"
    policy.img_src     :self, :https, :data, :blob
    policy.media_src   :self, :https
    policy.object_src  :none
    policy.frame_ancestors :self
    policy.script_src  :self, :https, :unsafe_inline,
                       "https://cdn.jsdelivr.net",
                       "https://mc.webvisor.org",
                       "https://mc.yandex.ru"
    policy.style_src   :self, :https, :unsafe_inline,
                       "https://fonts.googleapis.com",
                       "https://cdn.jsdelivr.net"
    policy.connect_src :self, :https, :wss,
                       "https://api.telegram.org",
                       "https://mc.yandex.ru"
    policy.worker_src  :self, :blob
    policy.form_action :self

    # CSP violation reports → наш endpoint.
    policy.report_uri "/csp_violations"
  end

  # Report-only режим: только отчёты, без блокировок. После наблюдения
  # ~2 недель и устранения всех false-positive — поменять на false.
  config.content_security_policy_report_only = true
end
