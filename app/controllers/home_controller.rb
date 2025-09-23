class HomeController < ApplicationController
  def index
    @gallery_images = Image.order(created_at: :desc).limit(6)
  end
end
