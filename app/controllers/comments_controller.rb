class CommentsController < ApplicationController

  before_filter :get_parent

  def new
    @comment = @parent.comments.build
  end

  def create
    @comment = @parent.comments.build(comment_params)
    @comment.commenter = current_user

    if @comment.save
      if send_mails
        redirect_to project_path(@comment.project), :notice => 'Thank you for your comment!'
      else
        redirect_to project_path(@comment.project), :notice => 'Thank you for your comment!. But failed to send mails.'
      end
    else
      render :new
    end
  end

  def comment_params
    params.require(:comment).permit(:commentable_id, :commentable_type, :commenter_id, :text, :commenter)
  end

  protected

  def get_parent
    @parent = Project.find_by_id(params[:project_id]) if params[:project_id]
    @parent = Comment.find_by_id(params[:comment_id]) if params[:comment_id]

    redirect_to root_path unless defined?(@parent)
  end

  private

  def send_mails
    if !ENV['SEND_EMAIL_ON_COMMENT_ADD'] || ENV['SEND_EMAIL_ON_COMMENT_ADD'] != 'true'
      return true
    end

    ret = true

    message_body1 = "Project Title : " + @comment.project.title + "\n"
    message_body2 = "Comment : " + @comment.text + "\n\n\n"
    message_body3 = "Project URL : " + request.base_url + project_path(@comment.project)

    message_body = message_body1 + message_body2 + message_body3

    message_start = @comment.commenter.name + " posted a comment against a project you created.\n\n"

    begin
      smtp = get_smtp_obj
      send_single_email smtp, message_body, @comment.project.originator, message_start

      if !@comment.project.users.empty?
        @comment.project.users.each do |user|
          if user.name == @comment.project.originator.name
            next
          end

          message_start = @comment.commenter.name + " posted a comment against a project you joined.\n\n"
          send_single_email smtp, message_body, user, message_start
        end
      end

      if @comment.commentable.is_a?(Comment)
        message_start = @comment.commenter.name + " replied to your comment on a project.\n\n"
        send_single_email smtp, message_body, @comment.commentable.commenter, message_start
      end
    rescue Exception => e
      puts "Exception while sending mails."
      puts e.message
      puts e.backtrace.inspect
      ret = false
    ensure
      if smtp
        smtp.finish
      end
    end

    return ret
  end

  def get_smtp_obj
    serverSMTP = ENV['SMTP_SERVER_ADDR'] ? ENV['SMTP_SERVER_ADDR'] : "localhost"
    portSMTP = ENV['SMTP_SERVER_PORT'] ? ENV['SMTP_SERVER_PORT'].to_i : 25
    userSMTP = ENV['SMTP_USER'] ? ENV['SMTP_USER'] : nil
    passwordSMTP = ENV['SMTP_PASSWORD'] ? ENV['SMTP_PASSWORD'] : nil
    return Net::SMTP.start(serverSMTP, portSMTP, 'localhost', userSMTP, passwordSMTP, :plain)
  end

  def send_single_email (smtp, message_body, receipant, message_start)
    message_header = "From: DO NOT REPLY <" + ENV['ADMIN_EMAIL_ADDRESS'] + ">\n" + "To: " + receipant.email + "\nSubject: Notification :: Comment posted against Hackfest project\n"
    message_greeting = "Hello " + receipant.name + ",\n\n"
    message = message_header + message_greeting + message_start + message_body

    smtp.send_message message, ENV['ADMIN_EMAIL_ADDRESS'], receipant.email
  end
end
