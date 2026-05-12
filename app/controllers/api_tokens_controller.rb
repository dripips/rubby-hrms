# Web-CRUD для API-токенов (не путать с Api::V1::* — это пользовательский UI).
class ApiTokensController < ApplicationController
  before_action :authenticate_user!

  def create
    name = params[:name].to_s.strip
    name = "API token" if name.blank?

    _record, raw = ApiToken.issue!(user: current_user, name: name)
    flash[:api_token_raw] = raw
    redirect_to security_profile_path
  end

  def destroy
    token = current_user.api_tokens.find(params[:id])
    token.destroy
    redirect_to security_profile_path,
                notice: t("profile.api_tokens.revoked", default: "Токен отозван")
  end
end
