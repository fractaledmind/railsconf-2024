require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  class UnauthenticatedTest < CommentsControllerTest
    setup do
      @comment = comments(:one)
    end

    test "shouldn't define index" do
      assert_raises NameError do
        get comments_url
      end
    end

    test "shouldn't define new" do
      assert_raises NameError do
        get new_comment_url
      end
    end

    test "shouldn't define create" do
      assert_raises NameError do
        post comments_url, params: { comment: { body: @comment.body, post_id: @comment.post_id, user_id: @comment.user_id } }
      end
    end

    test "shouldn't define show" do
      get comment_url(@comment)
      assert_response :not_found
    end

    test "shouldn't define edit" do
      get edit_comment_url(@comment)
      assert_response :not_found
    end

    test "shouldn't define update" do
      patch comment_url(@comment), params: { comment: { body: @comment.body, post_id: @comment.post_id, user_id: @comment.user_id } }
      assert_response :not_found
    end

    test "shouldn't define destroy" do
      assert_difference("Comment.count", 0) do
        delete comment_url(@comment)
      end

      assert_response :not_found
    end
  end

  class AuthenticatedTest < CommentsControllerTest
    setup do
      @comment = comments(:one)
      authenticate(user: @comment.user)
    end

    test "shouldn't define index" do
      assert_raises NameError do
        get comments_url
      end
    end

    test "shouldn't define new" do
      assert_raises NameError do
        get new_comment_url
      end
    end

    test "should create comment" do
      assert_difference("Comment.count", 1) do
        post post_comments_url(@comment.post), params: { comment: { body: "new comment" } }
      end

      assert_redirected_to post_url(@comment.post, anchor: "comment_#{Comment.last.id}")
    end

    test "shouldn't define show" do
      get comment_url(@comment)
      assert_response :not_found
    end

    test "should get edit" do
      get edit_comment_url(@comment)
      assert_response :success
    end

    test "should update comment" do
      patch comment_url(@comment), params: { comment: { body: @comment.body + "_updated" } }
      assert_redirected_to post_url(@comment.post, anchor: "comment_#{@comment.id}")
    end

    test "should destroy comment" do
      assert_difference("Comment.count", -1) do
        delete comment_url(@comment)
      end

      assert_redirected_to post_url(@comment.post)
    end
  end
end
