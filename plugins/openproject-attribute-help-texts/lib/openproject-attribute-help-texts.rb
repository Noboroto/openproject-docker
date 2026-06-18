# frozen_string_literal: true

# Standard OpenProject plugin entry point. OpenProject requires the file whose
# name matches the gem name ("openproject-attribute-help-texts"); that file in
# turn loads the Rails engine which performs the ActsAsOpEngine registration.
require "openproject/attribute_help_texts/version"
require "openproject/attribute_help_texts/engine"
