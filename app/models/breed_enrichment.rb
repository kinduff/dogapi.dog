# frozen_string_literal: true

# One attempt at filling in a breed's attributes from an external model, kept
# whether or not it was applied. The raw response is what makes a surprising
# value traceable back to the run and the prompt that produced it.
class BreedEnrichment < ApplicationRecord
  belongs_to :breed

  validates :model, presence: true

  scope :ordered, -> { order(created_at: :desc) }
  scope :applied, -> { where.not(applied_at: nil) }
  scope :rejected, -> { where(applied_at: nil) }

  def applied? = applied_at.present?
end
