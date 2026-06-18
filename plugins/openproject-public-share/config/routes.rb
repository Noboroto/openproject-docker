# frozen_string_literal: true

Rails.application.routes.draw do
  # Unauthenticated public view — dedicated top-level scope outside /projects
  # so OP's auth constraints don't apply and our path isn't shadowed.
  get  "/share/:token", to: "public_share/public#show", as: :public_share_show

  # Authenticated project-scoped management
  scope "/projects/:project_id/public_share" do
    resources :share_links, controller: "public_share/share_links",
              only: %i[index create destroy]
  end
end
