class DepositReviewsController < ApplicationController
  allow_unauthenticated_access

  def show
    head :not_found
  end

  def confirm
    head :not_found
  end

  def reject
    head :not_found
  end
end
