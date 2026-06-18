# frozen_string_literal: true

module PublicShare
  class ShareLink < ApplicationRecord
    self.table_name = "op_public_share_links"

    belongs_to :work_package, optional: true
    belongs_to :query,        optional: true
    belongs_to :creator, class_name: "User"

    validates :token_digest, presence: true, uniqueness: true
    validates :creator,      presence: true
    validate  :work_package_or_query_present

    scope :active, -> {
      where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current)
    }

    def active?
      revoked_at.nil? && (expires_at.nil? || expires_at.future?)
    end

    def revoke!
      update!(revoked_at: Time.current)
    end

    private

    def work_package_or_query_present
      if work_package_id.blank? && query_id.blank?
        errors.add(:base, "work package or query must be present")
      end
    end
  end
end
