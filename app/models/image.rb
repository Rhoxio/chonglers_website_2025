class Image < ApplicationRecord
  validates :title, presence: true
  validates :cloudinary_public_id, presence: true, uniqueness: true
  validates :cloudinary_url, presence: true

  def self.upload_from_file(file, title: nil, description: nil)
    # Validate file size (max 10MB)
    if file.size > 10.megabytes
      raise "File size too large. Maximum allowed size is 10MB."
    end

    # Upload with retry logic and better error handling
    result = upload_with_retry(file)

    create!(
      title: title || File.basename(file.original_filename, ".*"),
      description: description,
      cloudinary_public_id: result["public_id"],
      cloudinary_url: result["secure_url"]
    )
  end

  def url(transformation: {})
    return cloudinary_url if transformation.empty?

    Cloudinary::Utils.cloudinary_url(cloudinary_public_id, transformation)
  end

  def thumbnail(width: 150, height: 150)
    Cloudinary::Utils.cloudinary_url(cloudinary_public_id,
      width: width, height: height, crop: :fill, gravity: :center
    )
  end

  def gallery_thumbnail
    Cloudinary::Utils.cloudinary_url(cloudinary_public_id,
      width: 400, height: 300, crop: :fill, gravity: :center
    )
  end

  def admin_thumbnail
    Cloudinary::Utils.cloudinary_url(cloudinary_public_id,
      width: 300, height: 200, crop: :fill, gravity: :center
    )
  end

  def resize(width: nil, height: nil)
    transformation = {}
    transformation[:width] = width if width
    transformation[:height] = height if height
    transformation[:crop] = "scale" if width || height

    url(transformation: transformation)
  end

  def destroy_from_cloudinary
    Cloudinary::Uploader.destroy(cloudinary_public_id) if cloudinary_public_id
    destroy
  end

  private

  def self.upload_with_retry(file, max_retries: 3)
    retries = 0

    begin
      # Upload with extended timeout and chunked upload for large files
      options = {
        timeout: 120,
        chunk_size: 6_000_000,
        resource_type: "auto"
      }

      # For larger files, use chunked upload
      if file.size > 5.megabytes
        options[:chunk_size] = 6_000_000
      end

      Cloudinary::Uploader.upload(file, options)

    rescue Net::TimeoutError, Net::WriteTimeout, Net::ReadTimeout => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "Cloudinary upload attempt #{retries} failed: #{e.message}. Retrying..."
        sleep(retries * 2) # Exponential backoff
        retry
      else
        raise "Upload failed after #{max_retries} attempts: #{e.message}"
      end
    rescue => e
      Rails.logger.error "Cloudinary upload error: #{e.message}"
      raise "Upload failed: #{e.message}"
    end
  end
end
