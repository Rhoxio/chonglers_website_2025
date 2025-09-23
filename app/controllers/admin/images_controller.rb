class Admin::ImagesController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required!
  before_action :set_image, only: [:show, :destroy]

  def index
    @images = Image.order(created_at: :desc)
    @images_count = Image.count
  end

  def show
  end

  def new
    @image = Image.new
  end

  def create
    if params[:image] && params[:image][:file]
      begin
        # Validate file type
        unless valid_image_type?(params[:image][:file])
          raise "Invalid file type. Please upload JPG, PNG, or GIF files only."
        end

        @image = Image.upload_from_file(
          params[:image][:file],
          title: params[:image][:title],
          description: params[:image][:description]
        )
        redirect_to admin_images_path, notice: "Image uploaded successfully!"
      rescue => e
        Rails.logger.error "Image upload failed: #{e.message}"
        flash.now[:alert] = "Error uploading image: #{e.message}"
        @image = Image.new(image_params.except(:file))
        render :new, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = "Please select an image to upload."
      @image = Image.new
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    if @image.destroy_from_cloudinary
      redirect_to admin_images_path, notice: "Image deleted successfully!"
    else
      redirect_to admin_images_path, alert: "Error deleting image."
    end
  end

  private

  def set_image
    @image = Image.find(params[:id])
  end

  def image_params
    params.require(:image).permit(:title, :description, :file)
  end

  def valid_image_type?(file)
    return false unless file.respond_to?(:content_type)

    allowed_types = %w[image/jpeg image/jpg image/png image/gif]
    allowed_types.include?(file.content_type.downcase)
  end
end