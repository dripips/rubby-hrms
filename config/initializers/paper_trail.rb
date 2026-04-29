# Extend PaperTrail's YAML deserialization with classes that show up in
# `object` / `object_changes` columns: BigDecimal (decimal columns), Symbol
# (used by Rails state-machine-style enums), TimeWithZone / TimeZone, Date.
# Without these, `version.reify` raises Psych::DisallowedClass and revert fails.

require "bigdecimal"

module PaperTrail
  module Serializers
    module YAML
      module_function

      EXTRA_PERMITTED = [
        Time, Date, DateTime, BigDecimal, Symbol,
        ActiveSupport::TimeWithZone, ActiveSupport::TimeZone,
        ActiveSupport::HashWithIndifferentAccess
      ].freeze

      def load(string)
        ::YAML.safe_load(string, permitted_classes: EXTRA_PERMITTED, aliases: true)
      end

      def dump(object)
        ::YAML.dump(object)
      end
    end
  end
end
