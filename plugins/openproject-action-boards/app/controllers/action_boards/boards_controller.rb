# frozen_string_literal: true

module ActionBoards
  # Project-scoped board management + rendering.
  #
  # `index`/`show` require :view_action_boards; `new`/`create`/`destroy` require
  # :manage_action_boards. The mapping lives in the engine's permission block and
  # is enforced by OpenProject's `authorize` before_action (which infers the
  # permission from controller_name/action_name and the current @project).
  class BoardsController < ::ApplicationController
    before_action :find_project
    before_action :authorize
    before_action :find_board, only: %i[show destroy]

    menu_item :action_boards

    def index
      @boards = boards_scope.order(:name)
    end

    def show
      @columns = @board.columns.ordered.to_a
      @cards_by_column = group_cards
    end

    def new
      @board = boards_scope.new
    end

    def create
      @board = boards_scope.new(board_params)
      if @board.save
        build_columns_for(@board)
        flash[:notice] = t(:"action_boards.created")
        redirect_to project_action_board_path(@project, @board)
      else
        flash.now[:error] = @board.errors.full_messages.to_sentence
        render :new
      end
    end

    def destroy
      @board.destroy
      flash[:notice] = t(:"action_boards.deleted")
      redirect_to project_action_boards_path(@project)
    end

    private

    def boards_scope
      ActionBoards::Board.where(project: @project)
    end

    def find_board
      @board = boards_scope.find(params[:id])
    end

    # Loads the project's visible work packages and buckets them per column by the
    # board's grouping attribute. `WorkPackage.visible` enforces read ACL so a user
    # never sees a card they cannot access.
    # VERIFY: the `.visible(user)` scope name against the running 17-slim image.
    def group_cards
      attribute = @board.grouping_attribute
      work_packages = @project.work_packages
                              .visible(current_user)
                              .includes(:status, :assigned_to, :type)
      grouped = work_packages.group_by { |wp| wp.public_send(attribute) }
      @columns.index_with { |column| Array(grouped[column.value_id]) }
    end

    def board_params
      params.require(:board).permit(:name, :action_type)
    end

    # Auto-populates columns from the project's available values for the chosen
    # action_type, so a freshly created board is immediately usable. Admins can
    # refine columns later (reorder / remove).
    def build_columns_for(board)
      candidates =
        case board.action_type
        when "status"   then ::Status.order(:position).map { |s| [s.name, s.id] }
        when "assignee" then @project.principals.order(:lastname).map { |u| [u.name, u.id] }
        when "version"  then @project.versions.order(:name).map { |v| [v.name, v.id] }
        else []
        end

      candidates.each_with_index do |(title, value_id), index|
        board.columns.create(title:, value_id:, position: index)
      end
    end

    # @project is required by OpenProject's `authorize`. We resolve it explicitly
    # from the routed :project_id to avoid depending on a version-specific helper.
    def find_project
      @project = Project.find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end
