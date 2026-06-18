# frozen_string_literal: true

module PlaceholderUsers
  # A login-less principal used for resource planning before a real account
  # exists. Stored via Single Table Inheritance on the shared `users` table
  # (the same table that backs ::User and ::Group, all subclasses of
  # ::Principal). The STI `type` value is the fully-qualified class name
  # "PlaceholderUsers::PlaceholderUser" — deliberately DISTINCT from core's
  # Enterprise-gated "PlaceholderUser" so the two never collide.
  #
  # SECURITY: authentication is structurally impossible. Every credential /
  # session path is overridden to return a non-authenticating value, and the
  # record carries no usable login or password. See spec for the proof.
  class PlaceholderUser < ::Principal
    validates :name, presence: true

    # ---- Display -----------------------------------------------------------
    # Principal#name is meant to be overridden by subclasses. Placeholders have
    # no firstname/lastname/login formatting — store the label in `lastname`
    # (a real column on `users`) and surface it here.
    # verify: Principal/User expose `lastname` on the users table (STI). If the
    # column name differs on the running image, adjust `name`/`name=`.
    def name
      read_attribute(:lastname).presence || super
    end

    def name=(value)
      write_attribute(:lastname, value)
    end

    # ---- Authentication: always denied ------------------------------------
    # Devise/Warden-style hook used by core (`status` -> active? gate). Even if
    # something flips the status, this hard-stops it.
    def active_for_authentication?
      false
    end

    # Core's User#check_password? verifies LDAP / local UserPassword. A
    # placeholder has neither and must always fail the check.
    def check_password?(_clear_password)
      false
    end

    # No password may ever be assigned or stored.
    def password=(*)
      nil
    end

    def password
      nil
    end

    def force_password_change
      false
    end

    # Placeholders have no email; guards notification/mailer code that assumes
    # every principal can be emailed.
    def mail
      nil
    end

    def mail=(*)
      nil
    end

    # No usable login handle (prevents login enumeration / accidental sign-in).
    def login
      nil
    end

    def login=(*)
      nil
    end

    # Treated as never-logged-in for any session/"is this principal online?"
    # check that core may perform.
    def logged?
      false
    end

    # Belt-and-suspenders: even if a caller bypasses check_password?, the
    # bcrypt/LDAP path has nothing to match.
    def auth_source
      nil
    end
  end
end
