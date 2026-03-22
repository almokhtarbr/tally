class UserProfile < ApplicationRecord
  belongs_to :project
  has_many :events, dependent: :nullify
  has_many :identity_aliases, dependent: :destroy

  validates :external_id, presence: true, uniqueness: { scope: :project_id }

  def merge_properties!(new_properties)
    merged = properties.dup
    new_properties.each do |key, value|
      if value.nil?
        merged.delete(key.to_s)
      else
        merged[key.to_s] = value
      end
    end
    update!(properties: merged)
  end
end
