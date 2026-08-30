class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    render plain: "Signed in as #{current_user.email} via #{warden.winning_strategy.class}"
  end
end
