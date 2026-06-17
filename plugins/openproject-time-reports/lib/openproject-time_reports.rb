# frozen_string_literal: true

# Standard OpenProject plugin entry point. OpenProject requires the file whose
# name matches the gem name ("openproject-time_reports"); that file loads the
# Rails engine which performs the ActsAsOpEngine registration.
require "openproject/time_reports/version"
require "openproject/time_reports/engine"
