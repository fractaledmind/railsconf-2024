require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  class UnauthenticatedTest < UsersControllerTest
    setup do
      @user = users(:one)
    end

    test "shouldn't define index" do
      get users_url
      assert_response :not_found
    end

    test "should get new" do
      get new_user_url
      assert_response :success
    end

    test "should create user" do
      assert_difference("User.count") do
        post users_url, params: { user: { screen_name: "new_user", password: "secret12", password_confirmation: "secret12" } }
      end

      assert_redirected_to user_url(User.last)
    end

    test "should show user" do
      get user_url(@user)
      assert_response :success
    end

    test "shouldn't define edit" do
      get edit_user_url(@user)
      assert_response :not_found
    end

    test "shouldn't define update" do
      patch user_url(@user), params: { user: { screen_name: @user.screen_name + "_updated", password: "secret12", password_confirmation: "secret12" } }
      assert_response :not_found
    end

    test "shouldn't define destroy" do
      assert_difference("User.count", 0) do
        delete user_url(@user)
      end

      assert_response :not_found
    end
  end

  class AuthenticatedTest < UsersControllerTest
    setup do
      @user = users(:one)
      authenticate(user: @user)
    end

    test "shouldn't define index" do
      get users_url
      assert_response :not_found
    end

    test "should get new" do
      get new_user_url
      assert_response :success
    end

    test "should create user" do
      assert_difference("User.count") do
        post users_url, params: { user: { screen_name: "new_user", password: "secret12", password_confirmation: "secret12" } }
      end

      assert_redirected_to user_url(User.last)
    end

    test "should show user" do
      get user_url(@user)
      assert_response :success
    end

    test "should get edit" do
      get edit_user_url(@user)
      assert_response :success
    end

    test "should update user" do
      patch "/user", params: { user: { screen_name: @user.screen_name + "_updated", password: "secret12", password_confirmation: "secret12" } }
      assert_redirected_to user_url(@user)
    end

    test "should destroy user" do
      assert_difference("User.count", -1) do
        delete "/user"
      end

      assert_redirected_to users_url
    end
  end
end
