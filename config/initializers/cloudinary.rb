# Cloudinary configuration
if ENV['CLOUDINARY_URL'].present?
  Cloudinary.config do |config|
    # Increase timeout for large file uploads
    config.timeout = 120  # 2 minutes
    config.chunk_size = 6_000_000  # 6MB chunks for large files

    # Connection settings
    config.open_timeout = 30
    config.read_timeout = 120
  end
end