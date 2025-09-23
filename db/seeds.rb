# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create admin user
admin_email = "admin@chonglers.com"
admin_password = "admin123"

admin_user = User.find_or_create_by!(email: admin_email) do |user|
  user.password = admin_password
  user.password_confirmation = admin_password
  user.admin = true
end

# Ensure admin status is set
admin_user.update!(admin: true) unless admin_user.admin?

puts "Admin user created: #{admin_email}"
puts "Password: #{admin_password}"
puts "Admin status: #{admin_user.admin?}"
