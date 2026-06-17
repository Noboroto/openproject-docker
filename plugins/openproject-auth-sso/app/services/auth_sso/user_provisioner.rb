# frozen_string_literal: true

module AuthSso
  # Find-or-create an OpenProject user from an `omniauth.auth` hash.
  #
  # Security invariants (enforced here, covered by specs):
  #   * NEVER sets `admin = true`. SSO users get the instance default (non-admin)
  #     global role only. There is no code path in this service that grants admin.
  #   * Rejects an auth hash with no email (cannot safely identify/provision).
  #   * Honors an optional email-domain allowlist (plugin setting) to prevent open
  #     self-registration via the IdP.
  #   * Existing users are matched first by SSO identity_url, then by email, so we
  #     reuse accounts on subsequent logins instead of duplicating them.
  #
  # NEVER log the auth hash or any secret — it can contain tokens/PII.
  class UserProvisioner
    Result = Struct.new(:user, :error, keyword_init: true) do
      def success? = user.present? && error.nil?
    end

    def initialize(provider, auth)
      @provider = provider
      @auth     = auth
    end

    # Returns a User on success, or nil on rejection (see #error for the reason).
    # Use #result for the structured outcome.
    def call
      result.user
    end

    def result
      @result ||= provision
    end

    def error
      result.error
    end

    private

    def provision
      email = extract(@provider.mapping_email.presence || "email")
      email = @auth.dig("info", "email") if email.blank?
      return Result.new(error: :missing_email) if email.blank?
      return Result.new(error: :domain_not_allowed) unless email_domain_allowed?(email)

      user = find_existing_user(email)
      if user.nil?
        return Result.new(error: :provisioning_disabled) if auto_provisioning_disabled?

        user = build_user(email)
      else
        update_identity!(user)
      end

      Result.new(user: user)
    end

    # Match an already-provisioned user: first by the SSO identity_url (stable
    # across email changes), then — only when safe — by email.
    def find_existing_user(email)
      by_identity = ::User.find_by(identity_url: identity_url)
      return by_identity if by_identity

      # SECURITY: linking an SSO login to a pre-existing LOCAL account by email is
      # an account-takeover vector — an attacker can register an IdP account using
      # a victim's email and inherit the victim's OP account. So the email fallback
      # is gated: the IdP must assert the email is verified AND an admin must have
      # explicitly enabled email linking for SSO (setting `allow_email_linking`,
      # default OFF). When not allowed, we return nil so a FRESH account is created
      # (build_user) instead of hijacking an existing one.
      return nil unless email_linking_allowed?

      # VERIFY against the running 17-slim image: OP stores emails on the User
      # (`mail`) and on `UserEmail`/`EmailAddress`. `User.find_by(mail:)` is the
      # canonical lookup in current OP.
      ::User.find_by(mail: email)
    end

    # Email linking permitted only if (a) admin opted in AND (b) the IdP asserts
    # the email is verified. Both default to false/absent → safe by default.
    def email_linking_allowed?
      return false unless ActiveModel::Type::Boolean.new.cast(settings["allow_email_linking"])

      email_verified_claim?
    end

    def email_verified_claim?
      claim = @auth.dig("info", "email_verified")
      claim = @auth.dig("extra", "raw_info", "email_verified") if claim.nil?
      ActiveModel::Type::Boolean.new.cast(claim) == true
    end

    def build_user(email)
      first, last = split_name(extract(@provider.mapping_name.presence || "name"))

      # Build the User directly (no Users::CreateService) to keep the service
      # self-contained and unit-testable. We explicitly DO NOT pass admin:.
      # VERIFY against the running image: OP User requires firstname/lastname/mail
      # and a unique login; `register!`/`activate` semantics may differ by version.
      user = ::User.new(
        login:        unique_login_from(email),
        mail:         email,
        firstname:    first,
        lastname:     last,
        identity_url: identity_url,
        admin:        false # SECURITY: never auto-grant admin. Do not change.
      )

      # Activate immediately — the IdP vouches for the identity. Language/notification
      # defaults come from OP settings.
      user.activate if user.respond_to?(:activate)
      user.save!

      user
    end

    def update_identity!(user)
      # Link/refresh the SSO identity on an existing local account so future
      # logins match by identity_url. Never escalates privileges.
      return if user.identity_url == identity_url

      user.update_column(:identity_url, identity_url) if user.respond_to?(:update_column)
    end

    # ---- helpers -----------------------------------------------------------

    def identity_url
      uid = @auth["uid"].presence || @auth.dig("info", "email")
      "#{@provider.strategy_name}:#{uid}"
    end

    def extract(field)
      return nil if field.blank?

      @auth.dig("info", field) || @auth.dig("extra", "raw_info", field)
    end

    def split_name(full)
      full = full.to_s.strip
      return ["SSO", "User"] if full.blank?

      parts = full.split(/\s+/, 2)
      [parts[0], parts[1].presence || parts[0]]
    end

    def unique_login_from(email)
      base = email
      login = base
      i = 1
      while ::User.exists?(login: login)
        i += 1
        login = "#{base}-#{i}"
      end
      login
    end

    def email_domain_allowed?(email)
      raw = settings["email_domain_allowlist"].to_s
      return true if raw.blank?

      allowed = raw.split(/[\s,]+/).map { |d| d.strip.downcase.delete_prefix("@") }.reject(&:blank?)
      return true if allowed.empty?

      domain = email.to_s.split("@").last.to_s.downcase
      allowed.include?(domain)
    end

    def auto_provisioning_disabled?
      ActiveModel::Type::Boolean.new.cast(settings["disable_auto_provisioning"])
    end

    def settings
      Setting.plugin_openproject_auth_sso || {}
    end
  end
end
