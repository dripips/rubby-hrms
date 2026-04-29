class StubController < ApplicationController
  def show
    @section = params[:section]
  end
end
