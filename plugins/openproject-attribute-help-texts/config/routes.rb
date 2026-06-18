# frozen_string_literal: true

# Intentionally empty.
#
# This plugin is a thin VIEW-HOOK-ONLY extension of OpenProject's built-in
# "Attribute help texts" feature. It exposes no controllers and therefore needs
# no routes. The admin CRUD UI is provided by core at
# /admin/attribute_help_texts (core AttributeHelpTextsController).
OpenProject::Application.routes.draw do
end
