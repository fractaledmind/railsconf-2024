class CommentsController < ApplicationController
  include ActionView::RecordIdentifier

  # ----- authenticated actions -----
  before_action :set_post, only: %i[ create ]
  before_action :set_and_authorize_comment, only: %i[ edit update destroy ]

  # GET /comments/1/edit
  def edit
  end

  # POST /comments
  def create
    @comment = @post.comments.new(comment_params)

    if @comment.save
      redirect_to post_path(@comment.post, anchor: dom_id(@comment)), notice: "Comment was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /comments/1
  def update
    if @comment.update(comment_params)
      redirect_to post_path(@comment.post, anchor: dom_id(@comment)), notice: "Comment was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /comments/1
  def destroy
    @comment.destroy!
    redirect_to post_path(@comment.post), notice: "Comment was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_post
      @post = Post.find(params[:post_id])
    end

    def set_and_authorize_comment
      @comment = Comment.find(params[:id])
      raise ApplicationController::NotAuthorized, "not allowed to #{action_name} this comment" unless @comment.user == Current.user
    end

    # Only allow a list of trusted parameters through.
    def comment_params
      params.require(:comment).permit(:body).merge(user_id: Current.user.id)
    end
end
