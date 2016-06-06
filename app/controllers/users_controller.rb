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
  
  def search
    @results = User.raw_search(params[:query])
  end
  
  def reindex
    @reindex = User.reindex
  end

  # GET /users/1
  # GET /users/1.json
  def show
    @users = User.all
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
        
        format.html { redirect_to @user, notice: 'User was successfully created.' }
        format.json { render :show, status: :created, location: @user }
      else
        format.html { render :new }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
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
