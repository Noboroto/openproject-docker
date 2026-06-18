# frozen_string_literal: true

module PublicShare
  # Strict read-only projection — only exposes explicitly allowlisted attributes.
  # NEVER expose: description (rich text with macros), attachments, watchers,
  # custom field values, private notes, or any relation data not in the allowlist.
  class ProjectionService
    WP_ATTRS = %i[id subject done_ratio updated_at].freeze

    def work_package(wp)
      {
        id:         wp.id,
        subject:    wp.subject,
        status:     wp.status&.name,
        type:       wp.type&.name,
        done_ratio: wp.done_ratio,
        updated_at: wp.updated_at&.iso8601
        # Intentionally omitted: description, attachments, custom_values,
        # watchers, relations, journals, assigned_to details.
      }
    end
  end
end
