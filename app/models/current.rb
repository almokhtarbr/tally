class Current < ActiveSupport::CurrentAttributes
  attribute :session

  def user
    session&.user
  end
end
