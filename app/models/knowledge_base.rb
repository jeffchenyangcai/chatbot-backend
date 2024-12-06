class KnowledgeBase < ApplicationRecord
  belongs_to :user
  has_many :files
end
