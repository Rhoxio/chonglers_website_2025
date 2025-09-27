# Database connection debugging - runs after database connection is established
Rails.application.config.after_initialize do
  Rails.logger.info "=== DATABASE DEBUG INFO ==="
  Rails.logger.info "Environment: #{Rails.env}"
  Rails.logger.info "DATABASE_URL: #{ENV['DATABASE_URL']}"

  begin
    config = ActiveRecord::Base.connection_db_config
    Rails.logger.info "Database config URL: #{config.url}"
    Rails.logger.info "Database name: #{config.database}"
    Rails.logger.info "Host: #{config.host}"

    # Test connection
    ActiveRecord::Base.connection.execute("SELECT version()")
    Rails.logger.info "✅ Database connection successful"

    # List existing databases
    databases = ActiveRecord::Base.connection.execute("SELECT datname FROM pg_database WHERE datistemplate = false")
    Rails.logger.info "Available databases: #{databases.map { |db| db['datname'] }.join(', ')}"

  rescue => e
    Rails.logger.error "❌ Database connection failed: #{e.class}: #{e.message}"
  end

  Rails.logger.info "=== END DATABASE DEBUG ==="
end