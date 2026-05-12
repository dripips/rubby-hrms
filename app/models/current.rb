# Per-request state, доступное во всех слоях (controller / model / job).
# Резетится автоматически Rails на каждом request'е.
#
# Использование:
#   Current.company  # — тенант текущего request'а (см. TenantResolver)
#   Current.user     # — devise current_user, дублируется для удобства из jobs
class Current < ActiveSupport::CurrentAttributes
  attribute :company, :user
end
