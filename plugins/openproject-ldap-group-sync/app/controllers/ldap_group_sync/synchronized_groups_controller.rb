# frozen_string_literal: true

module LdapGroupSync
  # Administration -> Authentication -> LDAP group sync.
  #
  # Admin-only CRUD of LDAP-group -> OP-group mappings, plus a "Sync now" action
  # that enqueues the background job. Admin-only via the core `require_admin`
  # filter (satisfies OP's zero-trust per-action auth check).
  class SynchronizedGroupsController < ::ApplicationController
    before_action :require_admin
    before_action :find_mapping, only: %i[edit update destroy sync]

    layout "admin"

    menu_item :ldap_group_sync

    def index
      @mappings = SynchronizedGroup.includes(:group).order(:id)
      @recent_runs = SyncRun.order(started_at: :desc).limit(20)
    end

    def new
      @mapping = SynchronizedGroup.new
    end

    def create
      @mapping = SynchronizedGroup.new(mapping_params)
      @mapping.confirm_privileged = confirm_privileged?

      if @mapping.save
        flash[:notice] = t(:"ldap_group_sync.flash.created")
        redirect_to action: :index
      else
        render :new
      end
    end

    def edit; end

    def update
      @mapping.confirm_privileged = confirm_privileged?

      if @mapping.update(mapping_params)
        flash[:notice] = t(:"ldap_group_sync.flash.updated")
        redirect_to action: :index
      else
        render :edit
      end
    end

    def destroy
      @mapping.destroy
      flash[:notice] = t(:"ldap_group_sync.flash.deleted")
      redirect_to action: :index
    end

    # Enqueue a sync for this single mapping.
    def sync
      SynchronizationJob.perform_later(synchronized_group_id: @mapping.id)
      flash[:notice] = t(:"ldap_group_sync.flash.sync_enqueued")
      redirect_to action: :index
    end

    # Enqueue a full sync of all mappings.
    def sync_all
      SynchronizationJob.perform_later
      flash[:notice] = t(:"ldap_group_sync.flash.sync_enqueued")
      redirect_to action: :index
    end

    private

    # IDOR-safe: scoped find (only one table, but never bare-find by params).
    def find_mapping
      @mapping = SynchronizedGroup.find(params[:id])
    end

    def mapping_params
      params.require(:synchronized_group)
            .permit(:ldap_auth_source_id, :group_id, :dn, :sync_users)
    end

    def confirm_privileged?
      ActiveModel::Type::Boolean.new.cast(params[:confirm_privileged])
    end
  end
end
