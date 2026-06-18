# frozen_string_literal: true

OpenProject::Application.routes.draw do
  # Mounted under /admin and namespaced so it does NOT collide with core's
  # Enterprise-gated /placeholder_users routes.
  scope "admin", as: "op_placeholder_users" do
    resources :placeholder_users,
              controller: "placeholder_users/placeholder_users",
              only: %i[index new create edit update destroy] do
      member do
        get  :convert, action: :convert_form
        post :convert, action: :convert
      end
    end
  end
end
