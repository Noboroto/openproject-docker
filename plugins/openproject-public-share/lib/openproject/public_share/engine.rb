# frozen_string_literal: true

require "open_project/plugins"

module OpenProject
  module PublicShare
    def self.feature_enabled?
      Setting.plugin_openproject_public_share.fetch("enabled", false).in?([true, "true"])
    end

    def self.kill_switch_active?
      Setting.plugin_openproject_public_share.fetch("kill_switch", false).in?([true, "true"])
    end

    class Engine < ::Rails::Engine
      engine_name :openproject_public_share

      include OpenProject::Plugins::ActsAsOpEngine

      initializer "openproject_public_share.zeitwerk_ignore_lib",
                  before: :set_autoload_paths do
        Rails.autoloaders.main.ignore(File.expand_path("../..", __dir__))
      end

      register "openproject-public_share",
               author_url: "https://example.com",
               bundled: false,
               settings: {
                 default: {
                   "enabled"          => false,
                   "default_ttl_days" => 7,
                   # Kill-switch: when true, all token lookups return nil (instant revoke-all).
                   "kill_switch"      => false
                 },
                 partial: "public_share/settings/plugin"
               } do

        project_module :public_share do
          permission :manage_public_shares,
                     { "public_share/share_links" => %i[index create destroy] },
                     permissible_on: :project
        end

        menu :project_menu,
             :public_share,
             { controller: "/public_share/share_links", action: :index },
             caption: :"public_share.title",
             icon: "share",
             after: :work_packages,
             if: ->(p) {
               OpenProject::PublicShare.feature_enabled? &&
                 p.module_enabled?(:public_share)
             }
      end

      # Rack::Attack throttle for the public endpoint (in case it is available).
      # OP ships rack-attack; if absent this block is a no-op.
      config.after_initialize do
        if defined?(Rack::Attack)
          Rack::Attack.throttle("public_share/ip", limit: 60, period: 60) do |req|
            req.ip if req.path.start_with?("/share/")
          end
        end
      end
    end
  end
end
