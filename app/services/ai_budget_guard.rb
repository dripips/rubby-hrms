# Защита от runaway AI costs.
#
# Логика:
#   • Soft-warning логируется при достижении 100% месячного бюджета (UI уже
#     показывает прогресс на /settings/ai dashboard).
#   • HARD-BLOCK срабатывает при достижении HARD_CAP_MULTIPLIER × budget
#     (по умолчанию 2.0 = 200% бюджета). Это поймёт runaway baddly до того
#     как счёт OpenAI разорёт.
#   • Кэшируется в Rails.cache на 60 секунд чтобы не считать SUM(cost_usd)
#     на каждом RunAiTaskJob.
#
# Если monthly_budget_usd = 0 (не задано) — guard выключен.
class AiBudgetGuard
  HARD_CAP_MULTIPLIER = (ENV["AI_HARD_CAP_MULTIPLIER"] || "2.0").to_f
  CACHE_TTL = 60.seconds

  class << self
    def over_budget?(setting)
      budget = setting.data["monthly_budget_usd"].to_f
      return false if budget <= 0

      month_spent >= budget * HARD_CAP_MULTIPLIER
    end

    def block_reason(setting)
      budget = setting.data["monthly_budget_usd"].to_f
      "budget_exceeded:spent=$#{month_spent.round(4)}/budget=$#{budget} " \
        "(hard cap = #{HARD_CAP_MULTIPLIER}x). " \
        "Increase budget in Settings → AI or wait until next month."
    end

    def month_spent
      Rails.cache.fetch("ai_budget:month_spent", expires_in: CACHE_TTL) do
        AiRun.where("created_at >= ?", Time.current.beginning_of_month).sum(:cost_usd).to_f
      end
    end

    # Сбросить кэш — после новых AiRun'ов чтобы цифры не замораживались.
    def invalidate_cache!
      Rails.cache.delete("ai_budget:month_spent")
    end
  end
end
