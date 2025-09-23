class ImagesController < ApplicationController
  before_action :set_image, only: [:show, :show_modal]

  def index
    @images = Image.order(created_at: :desc)
  end

  def show
  end

  def show_modal
    @gallery_images = Image.order(created_at: :desc).limit(6)
    @selected_index = @gallery_images.find_index(@image) || 0

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def set_image
    @image = Image.find(params[:id])
  end
end
