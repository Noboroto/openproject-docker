# frozen_string_literal: true

OpenProject::Application.routes.draw do
  # Administration -> Authentication -> LDAP group sync (admin only).
  scope "admin", as: "ldap_group_sync_admin" do
    resources :ldap_group_sync_synchronized_groups,
              controller: "ldap_group_sync/synchronized_groups",
              path: "ldap_group_sync",
              except: %i[show] do
      member do
        post :sync
      end
      collection do
        post :sync_all
      end
    end
  end
end
