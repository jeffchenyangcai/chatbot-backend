# class KnowledgeBase < ApplicationRecord
#   belongs_to :user
#   has_many :files
# end
class KnowledgeBase < ApplicationRecord
  has_many :file_record,foreign_key: 'knowledge_base_id', dependent: :destroy
  belongs_to :user
  validates :name, presence: true
end
