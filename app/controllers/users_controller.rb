class UsersController < ApplicationController
  # ----- unauthenticated actions -----
  with_options only: %i[ show new create ] do
    skip_before_action :ensure_user_authenticated!
    before_action :user_authenticated?
  end

  # GET /users/1
  def show
    @user = User.find(params[:id])
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # POST /users
  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to @user, notice: "Welcome! You have signed up successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # ----- authenticated actions -----
  with_options only: %i[ edit update destroy ] do
    before_action :set_current_user
  end

  # GET /users/1/edit
  def edit
  end

  # PATCH/PUT /users/1
  def update
    if @user.update(user_params)
      redirect_to @user, notice: "Profile was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /users/1
  def destroy
    @user.destroy!
    redirect_to users_url, notice: "Profile was successfully deleted.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_current_user
      @user = Current.user
    end

    # Only allow a list of trusted parameters through.
    def user_params
      params.require(:user).permit(:screen_name, :password, :password_confirmation, :about)
    end
end
