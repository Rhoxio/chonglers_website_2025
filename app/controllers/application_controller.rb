class ApplicationController < ActionController::Base
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
