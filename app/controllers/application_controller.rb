class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: { safari: 17.0, chrome: 119, firefox: 121, opera: 104, ie: false }
  before_action :ensure_user_authenticated!

  private

    def sign_in(user:)
      session = user.sessions.create!(
        user_agent: request.user_agent,
        ip_address: request.ip
      )
      user.update!(last_seen_at: Time.current)
      Current.session = session
      cookies.signed.permanent[Session::COOKIE_KEY] = {
        value: session.id,
        httponly: true,
        secure: !Rails.env.development? && ENV["RELAX_SSL"].blank?
      }
      true
    end

    def user_authenticated?
      return true if Current.session

      if (session = Session.find_by(id: cookies.signed[Session::COOKIE_KEY]))
        Current.session = session
        return true
      end

      false
    end

    def ensure_user_authenticated!
      return true if user_authenticated?

      redirect_to root_path
    end
end
