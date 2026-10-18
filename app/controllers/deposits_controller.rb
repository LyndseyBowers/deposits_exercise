class DepositsController < ApplicationController
  before_action :set_tradeline

  def index
    @deposits = @tradeline.deposits.order(:deposit_date, :id)
  end

  def show
    @deposit = @tradeline.deposits.find(params[:id])
  end

  def create
    @deposit = @tradeline.create_deposit(deposit_params)

    if @deposit.persisted?
      render :show, status: :created, location: tradeline_deposit_url(@tradeline, @deposit)
    else
      render_validation_errors(@deposit)
    end
  end

  private

  def set_tradeline
    @tradeline = Tradeline.find(params[:tradeline_id])
  end

  # Accepts { "deposit": { ... } } or, via JSON param wrapping, a bare { "amount": ..., "deposit_date": ... }.
  def deposit_params
    params.require(:deposit).permit(:amount, :deposit_date)
  end
end
