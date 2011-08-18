class MessagesController < ApplicationController
  before_filter :authenticate_user!
  
  def index
    @messages = current_user.received_messages
  end
  
  def create
    message = Message.new(params[:message])
    message.sender_id = current_user.id
    if message.save
      flash[:notice] = "you created a message"
      redirect_to '/'
      
      # Send a Pusher notification
      Pusher['private-'+params[:message][:recipient_id]].trigger('new_message', {:from => current_user.name, :subject => message.subject})
    else
      @user = User.find(params[:message][:recipient_id])
      render :action => 'users/show'
    end
  end
  
end
