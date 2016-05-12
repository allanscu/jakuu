class UserNotifier < ApplicationMailer
  default :from => 'allan@juscollege.com'

    # send a signup email to the user, pass in the user object that   contains the user's email address
    #def send_signup_email(user)
    #  @user = user
    #  mail( :to => @user.email,
    #  :subject => 'Thanks for signing up for our amazing app' )
    #end
    
    
    # sends a signup email with Postmark
    def send_signup_email(user)
      @user = user
      mail(
        :subject => 'Hello from Allan',
        :to  => @user.email)
    end
end
