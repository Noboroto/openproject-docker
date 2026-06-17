# frozen_string_literal: true

# Standard OpenProject plugin entry point. OpenProject requires the file whose
# name matches the gem name ("openproject-branding"); that file in turn loads the
# Rails engine which performs the ActsAsOpEngine registration.
require "openproject/branding/version"
require "openproject/branding/engine"
