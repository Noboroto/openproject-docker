# frozen_string_literal: true

module EmailDigests
  # Periodic digest email. One mail per user per run, listing the queued items.
  #
  # verify against running 17-slim image: core uses `ApplicationMailer` as the
  # mailer base. This mailer keeps to the plain ActionMailer API to avoid
  # coupling to internals; recipient locale is set explicitly.
  class DigestMailer < ::ApplicationMailer
    def digest(user, items, frequency: :daily)
      @user = user
      @items = Array(items)
      @frequency = frequency.to_sym

      with_locale_for(user) do
        mail to: user.mail,
             subject: I18n.t(:"email_digests.subject", count: @items.size)
      end
    end

    private

    def with_locale_for(user, &)
      locale = user.respond_to?(:language) && user.language.present? ? user.language : I18n.default_locale
      I18n.with_locale(locale, &)
    end
  end
end
