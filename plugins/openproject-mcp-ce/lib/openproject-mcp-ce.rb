# frozen_string_literal: true

# Standard OpenProject plugin entry point. OpenProject requires the file whose
# name matches the gem name ("openproject-mcp-ce"); that file loads the Rails
# engine which performs the ActsAsOpEngine registration.
require "openproject/mcp_ce/version"
require "openproject/mcp_ce/engine"
