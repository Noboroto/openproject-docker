# frozen_string_literal: true

module DateAlerts
  # Optional reminder email (opt-in per user). The in-app notification is the
  # primary channel; this mail is a convenience extra.
  #
  # verify against running 17-slim image: core uses `ApplicationMailer` as the
  # mailer base and sets the recipient locale via `User.execute_as` / I18n. This
  # mailer keeps to the plain ActionMailer API to avoid coupling to internals.
  class Mailer < ::ApplicationMailer
    def alert(user, work_package, kind)
      @user = user
      @work_package = work_package
      @kind = kind.to_sym

      subject_key = @kind == :due ? :"date_alerts.notification_due"
                                  : :"date_alerts.notification_start"

      with_locale_for(user) do
        mail to: user.mail,
             subject: I18n.t(subject_key, subject: work_package.subject)
      end
    end

    private

    def with_locale_for(user, &)
      locale = user.respond_to?(:language) && user.language.present? ? user.language : I18n.default_locale
      I18n.with_locale(locale, &)
    end
  end
end
