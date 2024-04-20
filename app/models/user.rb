class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  validates :screen_name, presence: true, uniqueness: true
  validates :password, allow_nil: true, length: { minimum: 8 }
end
