require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  class UnauthenticatedTest < SessionsControllerTest
    setup do
      @session = sessions(:one)
    end

    test "shouldn't define index" do
      get sessions_url
      assert_response :not_found
    end

    test "should get new" do
      get new_session_url
      assert_response :success
    end

    test "should create session" do
      assert_difference("Session.count") do
        post sessions_url, params: { session: { user: { screen_name: @session.user.screen_name, password: "secret12" } } }
      end

      assert_redirected_to user_url(Session.last.user)
    end

    test "shouldn't define show" do
      get session_url(@session)
      assert_response :not_found
    end

    test "shouldn't define edit" do
      assert_raises NoMethodError do
        get edit_session_url(@session)
      end
    end

    test "shouldn't define update" do
      patch session_url(@session), params: { session: { user_id: @session.user_id } }
      assert_response :not_found
    end

    test "shouldn't define destroy" do
      assert_difference("Session.count", 0) do
        delete session_url(@session)
      end

      assert_response :not_found
    end
  end

  class AuthenticatedTest < SessionsControllerTest
    setup do
      @session = sessions(:one)
      authenticate(user: @session.user)
    end

    test "shouldn't define index" do
      get sessions_url
      assert_response :not_found
    end

    test "should get new" do
      get new_session_url
      assert_response :success
    end

    test "should create session" do
      assert_difference("Session.count") do
        post sessions_url, params: { session: { user: { screen_name: @session.user.screen_name, password: "secret12" } } }
      end

      assert_redirected_to user_url(Session.last.user)
    end

    test "shouldn't define show" do
      get session_url(@session)
      assert_response :not_found
    end

    test "shouldn't define edit" do
      assert_raises NoMethodError do
        get edit_session_url(@session)
      end
    end

    test "shouldn't define update" do
      patch session_url(@session), params: { session: { user_id: @session.user_id } }
      assert_response :not_found
    end

    test "should destroy session" do
      assert_difference("Session.count", -1) do
        delete session_url(@session)
      end

      assert_redirected_to user_url(@session.user)
    end
  end
end
