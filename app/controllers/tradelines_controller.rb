class TradelinesController < ApplicationController
  def index
    render json: Tradeline.all
  end

  def show
    render json: Tradeline.find(params[:id])
  end
end
