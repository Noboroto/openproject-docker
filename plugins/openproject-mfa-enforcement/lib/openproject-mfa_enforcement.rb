# frozen_string_literal: true

# Standard OpenProject plugin entry point. OpenProject requires the file whose
# name matches the gem name ("openproject-mfa_enforcement"); that file loads the
# Rails engine which performs the ActsAsOpEngine registration.
require "openproject/mfa_enforcement/version"
require "openproject/mfa_enforcement/engine"
