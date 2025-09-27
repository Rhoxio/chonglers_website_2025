class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :omniauthable

  # Admin functionality
  def admin?
    admin
  end

  def make_admin!
    update!(admin: true)
  end

  def remove_admin!
    update!(admin: false)
  end

  # OAuth functionality
  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email || "#{auth.uid}@discord.local"
      user.password = Devise.friendly_token[0, 20]
      user.discord_username = auth.info.name
      user.discord_avatar = auth.info.image
      user.provider = auth.provider
      user.uid = auth.uid
    end
  end

  def discord_user?
    provider == 'discord'
  end

  def display_name
    discord_username.presence || email
  end
end
