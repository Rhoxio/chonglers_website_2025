class ApplicationController < ActionController::Base
  protected

  # Devise redirect after sign out
  def after_sign_out_path_for(resource_or_scope)
    root_path
  end

  public

  # Admin helper methods
  def admin_required!
    unless current_user&.admin?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
    end
  end

  def admin?
    current_user&.admin?
  end

  helper_method :admin?
end
