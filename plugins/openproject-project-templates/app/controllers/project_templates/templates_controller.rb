# frozen_string_literal: true

module ProjectTemplates
  # Global (non-project) controller managing the template registry and the
  # "create project from template" flow.
  #
  # Authorization: every action is a GLOBAL permission, so we use OpenProject's
  # `authorize_global` before_action which infers the required global permission
  # from controller_name/action_name (mapped in the engine's permission block):
  #
  #   index/create/destroy     -> manage_project_templates
  #   gallery/new/instantiate  -> create_project_from_template
  #
  # `authorize_global` satisfies OpenProject's zero-trust "every action must check
  # authorization" rule. We do NOT use `no_authorization_required!` here because
  # these actions are genuinely permission-gated.
  #
  # VERIFY `authorize_global` exists and infers global permissions on the running
  # 17-slim image. If unavailable, fall back to:
  #   before_action { deny_access unless User.current.allowed_globally?(:perm) }
  # together with `no_authorization_required! :index, ...` to clear the check.
  class TemplatesController < ::ApplicationController
    before_action :authorize_global
    before_action :find_template, only: %i[destroy]

    layout "admin"

    menu_item :project_templates
    menu_item :project_templates_gallery, only: %i[gallery new instantiate]

    # --- manage_project_templates -------------------------------------------

    def index
      @templates = Template.includes(:project).order(:name)
      # Projects the current user can see that are not yet registered as templates.
      # VERIFY `Project.visible(user)` scope name on the running image.
      @candidate_projects =
        Project.visible(current_user)
               .where.not(id: Template.select(:project_id))
               .order(:name)
    end

    # Mark an existing (visible) project as a template.
    def create
      project = Project.visible(current_user).find(template_params[:project_id])
      template = Template.new(
        project:,
        name:        template_params[:name].presence || project.name,
        description: template_params[:description],
        is_public:   truthy?(template_params[:is_public])
      )

      if template.save
        flash[:notice] = t(:"project_templates.flash.template_created")
      else
        flash[:error] = template.errors.full_messages.to_sentence
      end
      redirect_to action: :index
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def destroy
      @template.destroy
      flash[:notice] = t(:"project_templates.flash.template_deleted")
      redirect_to action: :index
    end

    # --- create_project_from_template ---------------------------------------

    # Self-service gallery of templates the user may instantiate.
    def gallery
      @templates = visible_templates.order(:name)
    end

    # Form to enter the new project's name/identifier.
    def new
      @template = visible_templates.find(params[:template_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    # Perform the clone via the core Projects::CopyService.
    def instantiate
      template = visible_templates.find(params[:template_id])

      result = CreateFromTemplateService.new(
        template:,
        user:       current_user,
        attributes: instantiate_params
      ).call

      if result.success?
        flash[:notice] = t(:"project_templates.flash.project_created")
        redirect_to project_path(result.project)
      else
        flash[:error] = result.errors.to_sentence.presence ||
                        t(:"project_templates.errors.clone_failed")
        @template = template
        render :new
      end
    rescue ActiveRecord::RecordNotFound
      render_404
    rescue CreateFromTemplateService::TooLargeError => e
      flash[:error] = e.message
      redirect_to action: :gallery
    end

    private

    # A template is instantiable by the current user if it is public, or if the
    # user can manage templates (admins/managers see all). IDOR-safe scoping:
    # never load a bare Template.find(params[:id]).
    def visible_templates
      if User.current.allowed_globally?(:manage_project_templates)
        Template.includes(:project)
      else
        Template.public_templates.includes(:project)
      end
    end

    def find_template
      @template = Template.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def template_params
      params.require(:template).permit(:project_id, :name, :description, :is_public)
    end

    def instantiate_params
      params.require(:project).permit(:name, :identifier)
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
