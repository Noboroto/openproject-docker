# frozen_string_literal: true

# Standard OpenProject plugin entry point. OpenProject requires the file whose
# name matches the gem name ("openproject-date_alerts"); that file in turn loads
# the Rails engine which performs the ActsAsOpEngine registration.
require "openproject/date_alerts/version"
require "openproject/date_alerts/engine"
