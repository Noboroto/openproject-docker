# frozen_string_literal: true

module PublicShare
  # Authenticated controller: create / list / revoke share links.
  class ShareLinksController < ::ApplicationController
    before_action :require_login
    before_action :require_feature_enabled
    before_action :find_project_by_project_id
    before_action :authorize
    before_action :find_link, only: %i[destroy]

    menu_item :public_share

    def index
      @links = ShareLink.where(
        work_package_id: @project.work_package_ids
      ).order(created_at: :desc)
    end

    def create
      wp = @project.work_packages.find(params[:work_package_id])
      raw, digest = TokenService.new.generate
      ttl = Setting.plugin_openproject_public_share.fetch("default_ttl_days", 7).to_i

      @link = ShareLink.create!(
        work_package:  wp,
        creator:       User.current,
        token_digest:  digest,
        expires_at:    ttl.days.from_now
      )

      # Show raw token ONCE in the flash — never again.
      redirect_to project_public_share_share_links_path(@project),
                  notice: t("public_share.flash.created", token: raw)
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def destroy
      @link.revoke!
      redirect_to project_public_share_share_links_path(@project),
                  notice: t("public_share.flash.revoked")
    end

    private

    def require_feature_enabled
      render_404 unless OpenProject::PublicShare.feature_enabled?
    end

    def find_link
      @link = ShareLink.where(work_package_id: @project.work_package_ids).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end
