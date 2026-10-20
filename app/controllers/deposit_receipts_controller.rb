class DepositReceiptsController < ApplicationController
  allow_unauthenticated_access

  def show
    head :not_found
  end

  def update
    head :not_found
  end
end
