# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :pdf_styler do
    namespace :admin, path: "admin/pdf_styler" do
      resources :templates
    end
  end

  scope "/projects/:project_id" do
    post "pdf_styler/exports", to: "pdf_styler/exports#create",
         as: :pdf_styler_project_exports
  end
end
