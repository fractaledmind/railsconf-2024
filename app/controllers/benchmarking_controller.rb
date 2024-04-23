class BenchmarkingController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :ensure_user_authenticated!
  before_action :set_user_update_last_seen_at

  # POST /benchmarking/read_heavy
  def read_heavy
    act_and_respond(
      post_create:      0.10,
      comment_create:   0.10,
      post_destroy:     0.02,
      comment_destroy:  0.03,
      post_show:        0.25,
      posts_index:      0.25,
      user_show:        0.25,
    )
  end

  # POST /benchmarking/write_heavy
  def write_heavy
    act_and_respond(
      post_create:      0.25,
      comment_create:   0.25,
      post_destroy:     0.05,
      comment_destroy:  0.20,
      post_show:        0.05,
      posts_index:      0.15,
      user_show:        0.05,
    )
  end

  # POST /benchmarking/balanced
  def balanced
    act_and_respond(
      post_create:      0.17,
      comment_create:   0.17,
      post_destroy:     0.05,
      comment_destroy:  0.11,
      post_show:        0.17,
      posts_index:      0.17,
      user_show:        0.16,
    )
  end

  def post_create
    post = Post.create!(user: @user, title: "Post #{request.uuid}", description: format(request:))
    redirect_to post
  end

  def comment_create
    post = Post.where("id >= ?", rand(Post.minimum(:id)..Post.maximum(:id))).limit(1).first
    comment = Comment.create!(user: @user, post: post, body: "Comment #{request.uuid}")
    redirect_to comment.post
  end

  def post_destroy
    post = Post.where("id >= ?", rand(Post.minimum(:id)..Post.maximum(:id))).limit(1).first
    post.destroy!
    redirect_to posts_path
  end

  def comment_destroy
    comment = Comment.where("id >= ?", rand(Comment.minimum(:id)..Comment.maximum(:id))).limit(1).first
    comment.destroy!
    redirect_to comment.post
  end

  def post_show
    @post = Post.where("id >= ?", rand(Post.minimum(:id)..Post.maximum(:id))).limit(1).first
    render "posts/show", status: :ok
  end

  def posts_index
    @posts = Post.where("id >= ?", rand(Post.minimum(:id)..Post.maximum(:id))).limit(100)
    render "posts/index", status: :ok
  end

  def user_show
    render "users/show", status: :ok
  end

  private

    def set_user_update_last_seen_at
      @user = User.where("id >= ?", rand(User.minimum(:id)..User.maximum(:id))).limit(1).first
      @user.update!(last_seen_at: Time.now)
    end

    def act_and_respond(actions_with_weighted_distribution)
      action = actions_with_weighted_distribution.max_by { |_, weight| rand ** (1.0 / weight) }.first

      send(action)
    end

    def format(request:)
      request.headers.to_h.slice(
        "GATEWAY_INTERFACE",
        "HTTP_ACCEPT",
        "HTTP_HOST",
        "HTTP_USER_AGENT",
        "HTTP_VERSION",
        "ORIGINAL_FULLPATH",
        "ORIGINAL_SCRIPT_NAME",
        "PATH_INFO",
        "QUERY_STRING",
        "REMOTE_ADDR",
        "REQUEST_METHOD",
        "REQUEST_PATH",
        "REQUEST_URI",
        "SCRIPT_NAME",
        "SERVER_NAME",
        "SERVER_PORT",
        "SERVER_PROTOCOL",
        "SERVER_SOFTWARE",
        "action_dispatch.request_id",
        "puma.request_body_wait",
      ).map { _1.join(": ") }.join("\n")
    end
end
