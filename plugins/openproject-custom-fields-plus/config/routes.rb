# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :custom_fields_plus do
    namespace :admin, path: "admin/custom_fields_plus" do
      resources :fields
    end

    resources :values, only: %i[show update] do
      member do
        get  :show
        post :update
      end
    end
  end
end
