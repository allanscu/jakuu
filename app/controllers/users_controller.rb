class UsersController < ApplicationController
  before_action :set_user, only: [:show, :edit, :update, :destroy]
  
  #Twilio exception handler
  rescue_from StandardError do |exception|
    trigger_sms_alerts(exception)
  end
  
  def trigger_sms_alerts(e)
    @alert_message = "
      [This is a test] ALERT! 
      It appears the server is having issues. 
      Exception: #{e}. 
      Go to: http://newrelic.com for more details."
    @image_url = "http://howtodocs.s3.amazonaws.com/new-relic-monitor.png"

    @admin_list = YAML.load_file('config/administrators.yml')

    begin
      @admin_list.each do |admin|
        phone_number = admin['phone_number']
        send_message(phone_number, @alert_message, @image_url)
      end
    
      flash[:success] = "Exception: #{e}. Administrators will be notified."
    rescue
      flash[:alert] = "Something when wrong."
    end

    redirect_to '/'
  end

  # GET /users
  # GET /users.json
  def index
    @users = User.all
  end

  # GET /users/1
  # GET /users/1.json
  def show
    @users = User.all
    @hash = Gmaps4rails.build_markers(@users) do |user, marker|
      marker.lat user.latitude
      marker.lng user.longitude
    end
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit
  end

  # POST /users
  # POST /users.json
  def create
    @user = User.new(user_params)

    respond_to do |format|
      if @user.save
        # Save the user_id to the session object
        session[:user_id] = @user.id
        
        # Create user on Authy, will return an id on the object
        authy = Authy::API.register_user(
          email: @user.email,
          cellphone: @user.phone,
          country_code: "1"
        )
        if authy.ok?
          self.authy_id = authy.id
          #@user.update(authy_id: authy.id)
        else
          authy.errors # this will return an error hash
        end
        
        # Send an SMS to your user
        Authy::API.request_sms(id: @user.authy_id)
        
        # Deliver the signup email via SendGrid
        UserNotifier.send_signup_email(@user).deliver
        
        # Deliver Twilio SMS
        @twilio_phone_number = ENV['TWILIO_NUMBER']

        @twilio_client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']

        @twilio_client.account.messages.create(
          :from => @twilio_phone_number,
          :to => @user.phone,
          :body => "Hi #{@user.first_name}!  Thanks for signing up!"
        )
        
        format.html { redirect_to verify_path, notice: 'Please enter verification code' }
        format.json { render :show, status: :created, location: @user }
      else
        format.html { render :new }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def verify
    @user = current_user

    # Use Authy to send the verification token
    token = Authy::API.verify(id: @user.authy_id, token: params[:token])

    if token.ok?
      # Mark the user as verified for get /user/:id
      @user.update(verified: true)

      # Send an SMS to the user 'success'
      send_message("You did it! Signup complete :)")

      # Show the user profile
      redirect_to user_path(@user.id)
    else
      flash.now[:danger] = "Incorrect code, please try again"
      render :show_verify
    end
  end
  
  def resend
    @user = current_user
    Authy::API.request_sms(id: @user.authy_id)
    flash[:notice] = "Verification code re-sent"
    redirect_to verify_path
  end
  
  def send_message(message)
    @user = current_user
    
    # Deliver Twilio SMS
    @twilio_phone_number = ENV['TWILIO_NUMBER']

    @twilio_client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']

    @twilio_client.account.messages.create(
      :from => @twilio_phone_number,
      :to => @user.phone,
      :body => message
    )
    
    puts message.to
  end

  # PATCH/PUT /users/1
  # PATCH/PUT /users/1.json
  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to @user, notice: 'User was successfully updated.' }
        format.json { render :show, status: :ok, location: @user }
      else
        format.html { render :edit }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1
  # DELETE /users/1.json
  def destroy
    @user.destroy
    respond_to do |format|
      format.html { redirect_to users_url, notice: 'User was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def user_params
      params.require(:user).permit(:first_name, :last_name, :address_1, :address_2, :city, :state, :zip_code, :country, :email, :phone)
    end
end
