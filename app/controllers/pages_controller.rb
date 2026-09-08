# frozen_string_literal: true

class PagesController < ApplicationController
  def index
    @option = params[:option].presence || "ruby"

    if params[:toast]
      flash.now[:notice] = t("navbar.demo_toast")
      render :toast
    end
  end
end
