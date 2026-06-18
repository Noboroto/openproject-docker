# frozen_string_literal: true

module ProjectTemplates
  # Creates a NEW project from a template by delegating to the core
  # `Projects::CopyService`. We deliberately do NOT hand-clone: CopyService is the
  # same engine the built-in "Copy project" feature uses and already handles the
  # work-package hierarchy, custom field values, members/roles, versions,
  # categories, wiki and ACLs correctly.
  #
  # The new project is created as a regular project — OpenProject 17 requires a
  # `workspace_type` on every project; CopyService inherits it from the source, but
  # we pass `workspace_type: "project"` explicitly in the target attributes so the
  # result is always a plain project regardless of the source's type.
  #
  # Copy runs as `user` (NOT User.system) so core ACLs apply: a user can only copy
  # what they are allowed to see/create.
  class CreateFromTemplateService
    # Aspects forwarded to CopyService's `only:` list. Attachments are gated on the
    # plugin setting because they multiply storage.
    BASE_ASPECTS = %w[
      work_packages
      versions
      categories
      members
      wiki
      queries
    ].freeze

    Result = Struct.new(:success?, :project, :errors, keyword_init: true)

    def initialize(template:, user:, attributes:)
      @template   = template
      @user       = user
      # Sanitized target attributes (name, identifier, ...). Identifier uniqueness
      # is enforced by the core CreateService inside CopyService.
      @attributes = attributes.to_h.symbolize_keys
    end

    def call
      guard_size!

      target_attributes = @attributes.merge(workspace_type: "project")

      # VERIFY CopyService SIGNATURE against the running 17-slim image. Across
      # recent OpenProject releases the shape has been:
      #
      #   Projects::CopyService
      #     .new(user:, source:)
      #     .call(target_project_params: <Hash/ActionController::Params>,
      #           only: <Array<String>>)
      #
      # `target_project_params` carries the new project's attributes; `only`
      # selects which aspects to copy. The returned object is a
      # ServiceResult responding to `success?`, `result` (the new Project) and
      # `errors`/`message`. If the keyword names differ on this image, adjust here
      # ONLY — the controller/job depend on this Result struct, not on CopyService.
      service_result =
        ::Projects::CopyService
          .new(user: @user, source: @template.project)
          .call(target_project_params: target_attributes, only: copy_aspects)

      if service_result.success?
        Result.new(success?: true, project: service_result.result, errors: [])
      else
        Result.new(success?: false, project: nil,
                   errors: Array(extract_errors(service_result)))
      end
    end

    private

    def copy_aspects
      aspects = BASE_ASPECTS.dup
      aspects << "work_package_attachments" if copy_attachments?
      aspects
    end

    def copy_attachments?
      settings["copy_attachments"]
    end

    # Refuse to clone an oversized template in a single request (DoS / long
    # transaction). For very large templates, run this through a background job.
    def guard_size!
      max = settings["max_work_packages"].to_i
      return if max <= 0

      if @template.work_package_count > max
        raise TooLargeError, I18n.t("project_templates.errors.too_large", max:)
      end
    end

    def settings
      Setting.plugin_openproject_project_templates || {}
    end

    # ServiceResult error extraction differs slightly across versions; be liberal.
    def extract_errors(service_result)
      if service_result.respond_to?(:errors) && service_result.errors.respond_to?(:full_messages)
        service_result.errors.full_messages
      elsif service_result.respond_to?(:message)
        service_result.message
      else
        I18n.t("project_templates.errors.clone_failed")
      end
    end

    class TooLargeError < StandardError; end
  end
end
