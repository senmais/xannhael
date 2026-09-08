# frozen_string_literal: true

class PagesController < ApplicationController
  def index
    @option = params[:option].presence || "ruby"
  end
end