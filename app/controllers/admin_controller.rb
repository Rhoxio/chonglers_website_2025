class AdminController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required!

  def dashboard
    @users_count = User.count
    @admin_count = User.where(admin: true).count
    @images_count = Image.count
    @recent_users = User.order(created_at: :desc).limit(5)
  end

  def users
    @users = User.order(created_at: :desc)
  end

  def toggle_admin
    @user = User.find(params[:id])
    if @user == current_user
      redirect_to admin_users_path, alert: "You cannot modify your own admin status."
      return
    end

    if @user.admin?
      @user.remove_admin!
      flash[:notice] = "#{@user.email} is no longer an admin."
    else
      @user.make_admin!
      flash[:notice] = "#{@user.email} is now an admin."
    end

    redirect_to admin_users_path
  end

end
