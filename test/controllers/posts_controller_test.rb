require "test_helper"

class PostsControllerTest < ActionDispatch::IntegrationTest
  class UnauthenticatedTest < PostsControllerTest
    setup do
      @post = posts(:one)
    end

    test "should get index" do
      get posts_url
      assert_response :success
    end

    test "shouldn't define new" do
      get new_post_url
      assert_response :not_found
    end

    test "shouldn't define create" do
      assert_difference("Post.count", 0) do
        post posts_url, params: { post: { title: "new post", description: "description" } }
      end

      assert_response :not_found
    end

    test "should show post" do
      get post_url(@post)
      assert_response :success
    end

    test "shouldn't define edit" do
      get edit_post_url(@post)
      assert_response :not_found
    end

    test "shouldn't define update" do
      patch post_url(@post), params: { post: { title: @post.title + "_updated", description: @post.description } }
      assert_response :not_found
    end

    test "shouldn't define destroy" do
      assert_difference("Post.count", 0) do
        delete post_url(@post)
      end

      assert_response :not_found
    end
  end

  class AuthenticatedTest < PostsControllerTest
    setup do
      @post = posts(:one)
      authenticate(user: @post.user)
    end

    test "should get index" do
      get posts_url
      assert_response :success
    end

    test "should get new" do
      get new_post_url
      assert_response :success
    end

    test "should create post" do
      assert_difference("Post.count", 1) do
        post posts_url, params: { post: { title: "new post", description: "description" } }
      end

      assert_redirected_to post_url(Post.last)
    end

    test "should show post" do
      get post_url(@post)
      assert_response :success
    end

    test "should get edit" do
      get edit_post_url(@post)
      assert_response :success
    end

    test "should update post" do
      patch post_url(@post), params: { post: { title: @post.title + "_updated", description: @post.description } }
      assert_redirected_to post_url(@post)
    end

    test "should destroy post" do
      assert_difference("Post.count", -1) do
        delete post_url(@post)
      end

      assert_redirected_to posts_url
    end
  end
end
