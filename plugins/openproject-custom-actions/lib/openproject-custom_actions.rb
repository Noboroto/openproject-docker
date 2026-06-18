# frozen_string_literal: true

# Standard OpenProject plugin entry point. OpenProject requires the file whose
# name matches the gem name ("openproject-custom_actions"); that file in turn
# loads the Rails engine which performs the ActsAsOpEngine registration.
require "openproject/custom_actions/version"
require "openproject/custom_actions/engine"
