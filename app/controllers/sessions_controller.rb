class SessionsController < ApplicationController
  
  skip_before_action :require_login,
                      only: %i[new create]
  
  # ログイン画面を表示する
  def new
  end

  # ログイン処理を行う
  def create
    # 利用中のUserだけを検索する
    user = User.active.find_by(email: params[:email])

    # メールアドレスとパスワードが正しければログインする
    if user&.authenticate(params[:password])
      reset_session
      session[:user_id] = user.id

      redirect_to artifacts_path,
                  notice: t("flash.session.created")
    else
      flash.now[:alert] = t("flash.session.invalid")

      render :new,
              status: :unprocessable_entity
    end
  end

  # ログアウト処理を行う
  def destroy
    reset_session

    redirect_to new_session_path,
                notice: t("flash.session.destroyed")
  end
end