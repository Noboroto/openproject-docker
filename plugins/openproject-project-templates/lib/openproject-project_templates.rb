# frozen_string_literal: true

# Standard OpenProject plugin entry point. OpenProject requires the file whose
# name matches the gem name ("openproject-project_templates"); that file in turn
# loads the Rails engine which performs the ActsAsOpEngine registration.
require "openproject/project_templates/version"
require "openproject/project_templates/engine"
