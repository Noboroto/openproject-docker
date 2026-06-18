# frozen_string_literal: true

# Loaded from the engine's `config.to_prepare` (NOT an initializer): by then the
# core has loaded OpenProject::Hook::ViewListener AND Rails has autoloaded
# ApplicationHelper (which the hook base class includes). Requiring it earlier
# fails on an uninitialized ApplicationHelper.

module OpenProject
  module Branding
    # View-hook listener that injects the compiled theme CSS and favicon override
    # into every layout <head>.
    #
    # Uses OpenProject's official `OpenProject::Hook::ViewListener` API — no core
    # template is edited.
    #
    # VERIFY against the running 17-slim image: the hook name
    # `:view_layouts_base_html_head` is version-dependent. Confirm it still exists
    # with, e.g.:
    #   docker run --rm openproject/openproject:17-slim \
    #     grep -rn "call_hook :view_layouts_base_html_head" /app/app/views
    # If the constant/hook was renamed, update the `render_on` symbol below.
    class Hooks < ::OpenProject::Hook::ViewListener
      # `context` carries the controller/request; the partial reads it to honor
      # the `?branding=off` safe-mode escape hatch.
      render_on :view_layouts_base_html_head,
                partial: "branding/theme_head"
    end
  end
end
