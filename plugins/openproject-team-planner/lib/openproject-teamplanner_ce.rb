# frozen_string_literal: true

# Standard OpenProject plugin entry point. OpenProject requires the file whose
# name matches the gem name ("openproject-teamplanner_ce"); that file in turn loads
# the Rails engine which performs the ActsAsOpEngine registration.
require "openproject/teamplanner_ce/version"
require "openproject/teamplanner_ce/engine"
