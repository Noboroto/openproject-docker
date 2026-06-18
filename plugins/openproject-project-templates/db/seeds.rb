# frozen_string_literal: true

# Default seed for the Project Templates plugin.
#
# Registers OpenProject's bundled "Scrum project" demo project as a default,
# PUBLIC project template, so it shows up in the gallery (/project_templates/
# gallery) and the admin list on every fresh database — no manual marking needed.
#
# OpenProject runs each plugin engine's db/seeds.rb during the `seed_plugins_data`
# step of `rake db:seed`, AFTER the core demo data has created the project
# (verified against app/seeders/root_seeder.rb). This file is therefore the
# canonical place to register a built-in template.
#
# Idempotent: keyed on the source project, so re-seeding never duplicates it.
scrum = Project.find_by(identifier: "your-scrum-project")

if scrum.nil?
  Rails.logger.info("[project_templates] 'your-scrum-project' not found; skipped default template seed")
else
  template = ProjectTemplates::Template.find_or_initialize_by(project_id: scrum.id)
  template.name = scrum.name if template.name.blank?
  if template.description.blank?
    template.description = "Default Scrum template: product backlog, sprints and story/bug work-package types."
  end
  template.is_public = true

  if template.changed?
    template.save!
    Rails.logger.info("[project_templates] registered '#{scrum.name}' as the default project template")
  end
end
