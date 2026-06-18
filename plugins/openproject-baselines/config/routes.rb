# frozen_string_literal: true

Rails.application.routes.draw do
  scope "/projects/:project_id" do
    resources :baselines, controller: "baselines/baselines", only: %i[index show new create destroy]
  end
end
