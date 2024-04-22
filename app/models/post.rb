class Post < ApplicationRecord
  belongs_to :user, counter_cache: true
  has_many :comments, dependent: :destroy

  validates :title, presence: true, uniqueness: true, length: { minimum: 5 }
end
