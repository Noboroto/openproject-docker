# frozen_string_literal: true

module OpenProject
  module CustomFieldsPlus
    class FormHook < OpenProject::Hook::ViewListener
      render_on :work_packages_show_attributes,
                partial: "custom_fields_plus/hooks/wp_advanced_fields"

      def self.gate(project)
        OpenProject::CustomFieldsPlus.feature_enabled? &&
          project&.module_enabled?(:custom_fields_plus)
      end
    end
  end
end
