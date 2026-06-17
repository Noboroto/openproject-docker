# frozen_string_literal: true

module AuthSso
  # Handles the OmniAuth callback for our DB-configured SSO strategies.
  #
  # This is a PRE-AUTH controller: the user is not yet logged in when the IdP
  # redirects back. We therefore skip OP's "login required" filter for the
  # callback/failure actions only.
  #
  # BREAK-GLASS GUARANTEE: this controller adds an *additional* login path. It
  # never disables or replaces local-password login at `/login`. If every SSO
  # provider is misconfigured, admins can still sign in locally.
  class SessionsController < ::ApplicationController
    # VERIFY against the running 17-slim image: the exact name of OP's
    # "require login" before_action. In current OP it is `check_if_login_required`
    # (from the Accounts/Authentication concern). If renamed, update this skip.
    skip_before_action :check_if_login_required, raise: false
    skip_before_action :verify_authenticity_token, only: :callback, raise: false

    # GET/POST /auth/:provider/callback
    def callback
      auth = request.env["omniauth.auth"]
      return redirect_failure(:no_auth_hash) if auth.blank?

      provider = ::AuthSso::Provider.find_by(strategy_name: auth["provider"])
      return redirect_failure(:unknown_provider) if provider.nil?
      return redirect_failure(:provider_inactive) unless provider.active?

      provisioner = ::AuthSso::UserProvisioner.new(provider, auth)
      user = provisioner.call

      if user.nil?
        return redirect_failure(provisioner.error || :provisioning_failed)
      end

      unless user.respond_to?(:active?) && user.active?
        return redirect_failure(:inactive_user)
      end

      complete_login(user)
    end

    # GET /auth/failure  (OmniAuth default failure endpoint)
    def failure
      reason = params[:message].presence || "failed"
      flash[:error] = t(:"auth_sso.failed", reason: reason)
      redirect_to signin_path_safe
    end

    private

    # Log the user into OpenProject's session.
    #
    # VERIFY against the running 17-slim image: the canonical session-login helper.
    # Current OP exposes `login_user!(user)` via the Accounts::UserLogin concern
    # (also `successful_authentication`). We try the documented helper, then fall
    # back to setting the session/User.current so we never hard-fail the login.
    def complete_login(user)
      if respond_to?(:login_user!, true)
        login_user!(user)
      elsif respond_to?(:successful_authentication, true)
        successful_authentication(user)
      else
        # Minimal fallback — VERIFY: OP keys the session on :user_id.
        session[:user_id] = user.id
        User.current = user if defined?(User.current)
        redirect_to home_url_safe
      end
    end

    def redirect_failure(reason)
      flash[:error] = t(:"auth_sso.failed", reason: reason)
      redirect_to signin_path_safe
    end

    # Be defensive about route helper availability across OP versions.
    def signin_path_safe
      return signin_path if respond_to?(:signin_path)

      "/login"
    end

    def home_url_safe
      return my_page_path if respond_to?(:my_page_path)
      return home_url if respond_to?(:home_url)

      "/"
    end
  end
end
