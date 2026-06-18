# frozen_string_literal: true

# Standard OpenProject plugin entry point. OpenProject requires the file whose
# name matches the gem name ("openproject-placeholder_users"); that file in turn
# loads the Rails engine which performs the ActsAsOpEngine registration.
require "openproject/placeholder_users/version"
require "openproject/placeholder_users/engine"
