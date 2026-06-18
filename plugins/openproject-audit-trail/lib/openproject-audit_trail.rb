# frozen_string_literal: true

# Standard OpenProject plugin entry point. OpenProject requires the file whose
# name matches the gem name ("openproject-audit_trail"); that file loads the
# Rails engine which performs the ActsAsOpEngine registration.
require "openproject/audit_trail/version"
require "openproject/audit_trail/engine"
