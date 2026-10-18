class TradelinesController < ApplicationController
  def index
    @tradelines = Tradeline.with_deposits_total.order(:id)
  end

  def show
    @tradeline = Tradeline.with_deposits_total.find(params[:id])
  end
end
