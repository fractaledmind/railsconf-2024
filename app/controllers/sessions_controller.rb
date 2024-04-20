class SessionsController < ApplicationController
  # ----- unauthenticated actions -----
  with_options only: %i[ new create ] do
    skip_before_action :ensure_user_authenticated!
    before_action :user_authenticated?
  end

  # GET /sessions/new
  def new
    @session = Session.new
  end

  # POST /sessions
  def create
    user = User.authenticate_by(
      screen_name: session_params.dig(:user, :screen_name),
      password: session_params.dig(:user, :password)
    )

    if user
      sign_in(user: user)
      redirect_to user, notice: "You have been signed in.", status: :see_other
    else
      redirect_to sign_in_path(screen_name_hint: session_params.dig(:user, :screen_name)), alert: "That email or password is incorrect"
    end
  end

  # ----- authenticated actions -----
  with_options only: %i[ destroy ] do
    before_action :set_and_authorize_session
  end

  # DELETE /sessions/1
  def destroy
    @session.destroy!
    redirect_to @session.user, notice: "That session has been successfully logged out.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_and_authorize_session
      @session = Current.user.sessions.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def session_params
      params.require(:session).permit(user: [ :screen_name, :password ])
    end
end
