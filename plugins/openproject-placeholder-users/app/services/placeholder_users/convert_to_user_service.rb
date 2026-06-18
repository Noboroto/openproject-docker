# frozen_string_literal: true

module PlaceholderUsers
  # Promotes a PlaceholderUser into a real ::User in place.
  #
  # The record's primary key is NOT changed, so every existing
  # `work_packages.assigned_to_id` / `responsible_id` (and any other
  # principal-id reference) transfers automatically — no reassignment pass
  # needed. Only the STI `type` flips and the login/mail/status are populated.
  class ConvertToUserService
    # Tiny result object so the controller has a uniform success/errors shape
    # without depending on core's ServiceResult API surface (verify: core's
    # `ServiceResult` could be used instead if a richer contract is wanted).
    Result = Struct.new(:success, :user, :errors, keyword_init: true) do
      def success? = success
    end

    def initialize(placeholder, login:, mail:, current_user:)
      @placeholder  = placeholder
      @login        = login.to_s.strip
      @mail         = mail.to_s.strip
      @current_user = current_user
    end

    def call
      return failure(I18n.t(:"placeholder_users.errors.login_required")) if @login.blank?

      ApplicationRecord.transaction do
        flip_to_user!
        user = ::User.find(@placeholder.id)
        Result.new(success: true, user:, errors: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    rescue ActiveRecord::RecordNotUnique
      failure(I18n.t(:"placeholder_users.errors.login_taken"))
    end

    private

    # update_columns bypasses the PlaceholderUser no-auth overrides + validations
    # (which would block writing login/mail/password). We deliberately write the
    # raw STI columns, then reload as ::User so the real model's validations and
    # lifecycle apply on subsequent edits.
    #
    # verify: column names (`type`, `login`, `mail`, `status`) and the
    # `User.statuses[:invited]` enum value against the running image.
    def flip_to_user!
      attrs = {
        type: "User",
        login: @login,
        mail: @mail.presence
      }
      if ::User.respond_to?(:statuses) && ::User.statuses.key?("invited")
        attrs[:status] = ::User.statuses[:invited]
      end

      @placeholder.update_columns(attrs) # rubocop:disable Rails/SkipsModelValidations
    end

    def failure(message)
      Result.new(success: false, user: nil, errors: message)
    end
  end
end
