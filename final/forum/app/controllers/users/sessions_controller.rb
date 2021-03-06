class Users::SessionsController < Devise::SessionsController
  prepend_before_filter :require_no_authentication, only: [ :new, :create ]
  prepend_before_filter :allow_params_authentication!, only: :create
  prepend_before_filter :verify_signed_out_user, only: :destroy
  prepend_before_filter only: [ :create, :destroy ] { request.env["devise.skip_timeout"] = true }

  # GET /resource/sign_in
  # GET /users/recover
  def new
    parsed_url = request.original_url.split('/').reverse!
    if (parsed_url.size() > 1 && parsed_url[0] == "recover" && parsed_url[1] == "users")
      @submit_message = "Recover"
    else
      @submit_message = "Log in"
    end
    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    yield resource, @submit_message if block_given?
    respond_with(resource, serialize_options(resource), @submit_message)
  end

  # POST /resource/sign_in
  def create
    self.resource = warden.authenticate!(auth_options)
    if params[:commit] == "Log in" && resource.status == "active"
      # regular login
      set_flash_message(:notice, :signed_in) if is_flashing_format?
      sign_in(resource_name, resource)
      redirect_to root_path and return
    elsif resource.status == "deleted" && params[:commit] != "Recover"
      # a deleted user is trying to sign in
      signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
      set_flash_message :alert, :deleted if signed_out && is_flashing_format?
      yield if block_given?
      respond_to_on_destroy and return
    elsif params[:commit] == "Recover"
      # a deleted user is trying to recover account
      resource = User.new.where_email(params[:user][:email])
      resource.status = "active"
      resource.save!
      sign_in(resource_name, resource)
      redirect_to root_path, notice: "Account recovered...Signed in successfully." and return
    end
    # yield resource if block_given?
    # respond_with resource, location: after_sign_in_path_for(resource)
  end

  # DELETE /resource/sign_out
  def destroy
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message :notice, :signed_out if signed_out && is_flashing_format?
    yield if block_given?
    respond_to_on_destroy
  end

  protected

  def sign_in_params
    devise_parameter_sanitizer.sanitize(:sign_in)
  end

  def serialize_options(resource)
    methods = resource_class.authentication_keys.dup
    methods = methods.keys if methods.is_a?(Hash)
    methods << :password if resource.respond_to?(:password)
    { methods: methods, only: [:password] }
  end

  def auth_options
    { scope: resource_name, recall: "#{controller_path}#new" }
  end

  private

  # Check if there is no signed in user before doing the sign out.
  #
  # If there is no signed in user, it will set the flash message and redirect
  # to the after_sign_out path.
  def verify_signed_out_user
    if all_signed_out?
      set_flash_message :notice, :already_signed_out if is_flashing_format?

      respond_to_on_destroy
    end
  end

  def sign_up_params
    devise_parameter_sanitizer.sanitize(:sign_up)
  end

  def build_resource(hash=nil)
    self.resource = resource_class.new_with_session(hash || {}, session)
  end

  def all_signed_out?
    users = Devise.mappings.keys.map { |s| warden.user(scope: s, run_callbacks: false) }

    users.all?(&:blank?)
  end

  def respond_to_on_destroy
    # We actually need to hardcode this as Rails default responder doesn't
    # support returning empty response on GET request
    respond_to do |format|
      format.all { head :no_content }
      format.any(*navigational_formats) { redirect_to after_sign_out_path_for(resource_name) }
    end
  end
end