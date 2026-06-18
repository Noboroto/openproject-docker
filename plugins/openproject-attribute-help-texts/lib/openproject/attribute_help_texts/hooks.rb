# frozen_string_literal: true

# Loaded from the engine's `config.to_prepare` (NOT an initializer): by then the
# core has loaded OpenProject::Hook::ViewListener AND Rails has autoloaded
# ApplicationHelper (which the hook base class includes). Requiring it earlier
# fails on an uninitialized ApplicationHelper.

module OpenProject
  module AttributeHelpTexts
    # View-hook listener that injects a small, sanitized CSS + accessibility
    # enhancement for OpenProject's EXISTING (core) attribute help-text tooltips.
    #
    # This does NOT render help-text content itself — core already renders the "?"
    # trigger and the help-text dialog. We only style/improve the trigger so it is
    # easier to spot and keyboard-focusable.
    #
    # Uses OpenProject's official `OpenProject::Hook::ViewListener` API — no core
    # template is edited.
    #
    # VERIFY against the running 17-slim image: the hook name
    # `:view_layouts_base_html_head` is version-dependent (confirmed present in
    # OP 17, app/views/layouts/base.html.erb). If it is ever renamed, update the
    # `render_on` symbol below.
    class Hooks < ::OpenProject::Hook::ViewListener
      # `context` carries the controller/request; the partial reads it defensively
      # to honor the `?aht_enhance=off` safe-mode escape hatch.
      render_on :view_layouts_base_html_head,
                partial: "attribute_help_texts/head"
    end
  end
end
