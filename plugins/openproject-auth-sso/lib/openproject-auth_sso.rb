# frozen_string_literal: true

# Standard OpenProject plugin entry point. Bundler/OpenProject requires the file
# whose name matches the gem name ("openproject-auth_sso"); that file loads the
# Rails engine which performs the ActsAsOpEngine registration.
#
# NOTE: the gem name uses an underscore ("auth_sso") per the spec, so the entry
# file is `openproject-auth_sso.rb` (matches the gem name for `require`).
require "openproject/auth_sso/version"
require "openproject/auth_sso/engine"
