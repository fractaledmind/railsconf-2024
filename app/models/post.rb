class Post < ApplicationRecord
  belongs_to :user, counter_cache: true

  validates :title, presence: true, uniqueness: true, length: { minimum: 5 }
end
