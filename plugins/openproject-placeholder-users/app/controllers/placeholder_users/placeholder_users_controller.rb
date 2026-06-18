# frozen_string_literal: true

module PlaceholderUsers
  # Administration -> Placeholder users.
  #
  # Admin-only management of login-less placeholder principals. Guarded by
  # OpenProject's built-in `require_admin` on EVERY action (OP enforces a
  # zero-trust auth check on each controller action — a missing check raises
  # "Authorization check required" -> 500).
  class PlaceholderUsersController < ::ApplicationController
    before_action :require_admin

    layout "admin"

    menu_item :op_placeholder_users

    before_action :find_placeholder, only: %i[edit update destroy convert_form convert]

    def index
      @placeholders = PlaceholderUser.order(:lastname)
    end

    def new
      @placeholder = PlaceholderUser.new
    end

    def create
      @placeholder = PlaceholderUser.new(name: placeholder_params[:name])
      # Placeholders are inert for auth; mark them locked so no session/auth
      # subsystem ever treats them as a sign-in candidate.
      # verify: `:locked` is a valid Principal status enum key on the image.
      @placeholder.status = ::Principal.statuses[:locked] if ::Principal.respond_to?(:statuses)

      if @placeholder.save
        flash[:notice] = t(:"placeholder_users.flash.created")
        redirect_to action: :index
      else
        flash.now[:error] = @placeholder.errors.full_messages.to_sentence
        render :new
      end
    end

    def edit; end

    def update
      if @placeholder.update(name: placeholder_params[:name])
        flash[:notice] = t(:"placeholder_users.flash.updated")
        redirect_to action: :index
      else
        flash.now[:error] = @placeholder.errors.full_messages.to_sentence
        render :edit
      end
    end

    def destroy
      @placeholder.destroy
      flash[:notice] = t(:"placeholder_users.flash.deleted")
      redirect_to action: :index
    end

    # GET: render the "promote to real user" form.
    def convert_form
      render :convert
    end

    # POST: promote the placeholder into a real ::User, preserving its id so all
    # existing work-package assignments transfer automatically.
    def convert
      result = ConvertToUserService
               .new(@placeholder,
                    login: convert_params[:login],
                    mail: convert_params[:mail],
                    current_user: current_user)
               .call

      if result.success?
        flash[:notice] = t(:"placeholder_users.flash.converted")
        redirect_to action: :index
      else
        flash.now[:error] = result.errors
        render :convert
      end
    end

    private

    def find_placeholder
      # IDOR-safe: always scope to the placeholder STI subtype, never bare
      # Principal/User.find — a real User id must never resolve here.
      @placeholder = PlaceholderUser.find(params[:id])
    end

    def placeholder_params
      params.require(:placeholder_user).permit(:name)
    end

    def convert_params
      params.require(:placeholder_user).permit(:login, :mail)
    end
  end
end
