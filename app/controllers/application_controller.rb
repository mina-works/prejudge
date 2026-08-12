class ApplicationController < ActionController::Base
  before_action :require_login
  
  helper_method :current_user

  private

  # セッションに保存されたuser_idからログイン中のUserを取得する
  def current_user
    @current_user ||= User.find_by(
      id: session[:user_id]
    )
  end

  # 未ログインの場合はログイン画面へ移動させる
  def require_login
    return if current_user.present?

    redirect_to new_session_path,
                alert: t("flash.session.login_required")
  end
end