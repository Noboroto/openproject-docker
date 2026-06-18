# frozen_string_literal: true

module PublicShare
  # UNAUTHENTICATED controller — inherits ActionController::Base (NOT ApplicationController)
  # to stay completely outside OP's authentication stack. Token + feature flag only.
  #
  # Security contract:
  #   - Always returns 404 for bad/expired/revoked/kill-switch tokens (no oracle).
  #   - Returns only ProjectionService allowlist (no description, attachments, etc.).
  #   - No session, no cookies set, no CSRF token.
  #   - Rate-limited by Rack::Attack in the engine initializer.
  class PublicController < ::ActionController::Base
    layout "public_share/minimal"

    protect_from_forgery with: :null_session

    def show
      return head :not_found unless OpenProject::PublicShare.feature_enabled?

      link = TokenService.new.find_active(params[:token])
      return head :not_found unless link

      link.increment!(:access_count)

      if link.work_package
        @data = ProjectionService.new.work_package(link.work_package)
      else
        head :not_found
      end
    end
  end
end
