class Session < ApplicationRecord
  COOKIE_KEY = :session_token

  belongs_to :user

  def browser = @browser ||= Browser.new(user_agent)
end
