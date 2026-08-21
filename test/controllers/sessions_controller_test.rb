require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest

  setup do
    # ログインテストに使うUserをfixtureから取得する
    @user = users(:creator)
  end

  test "正しいemail・passwordでログインできる" do
    # 正しい認証情報でログインする
    post session_path, params: {
      email: @user.email,
      password: "password"
    }

    # ログインUserのIDがsessionに保存されることを確認する
    assert_equal @user.id, session[:user_id]

    # ログイン後、Artifact一覧画面へ移動することを確認する
    assert_redirected_to artifacts_url

    # ログイン成功メッセージが設定されることを確認する
    assert_equal I18n.t("flash.session.created"), flash[:notice]
  end

  test "ログイン済みUserがログアウトできる" do
    # ログインする
    log_in_as(@user)

    # ログインできていることを事前に確認する
    assert_equal @user.id, session[:user_id]

    # ログアウト処理を実行する
    delete session_path

    # ログアウト後、sessionのuser_idが削除されることを確認する
    assert_nil session[:user_id]

    # ログアウト後、ログイン画面へ移動することを確認する
    assert_redirected_to new_session_path

    # ログアウト成功メッセージが設定されることを確認する
    assert_equal I18n.t("flash.session.destroyed"), flash[:notice]
  end

  test "passwordが間違っている場合はログインできない" do
    # 間違ったpasswordでログインを試みる
    post session_path, params: {
      email: @user.email,
      password: "wrong_password"
    }

    # sessionにUser IDが保存されていないことを確認する
    assert_nil session[:user_id]

    # ログイン画面が422で再表示されることを確認する
    assert_response :unprocessable_entity

    # ログイン失敗を知らせるメッセージが設定される
    assert flash[:alert].present?
  end

  test "存在しないemailではログインできない" do
    # 存在しないemailでログインを試みる
    post session_path, params: {
      email: "wrong_email@example.com",
      password: "password"
    }

    # sessionにUser IDが保存されていないことを確認する
    assert_nil session[:user_id]

    # ログイン画面が422で再表示されることを確認する
    assert_response :unprocessable_entity

    # ログイン失敗を知らせるメッセージが設定される
    assert flash[:alert].present?
  end

  test "active: falseのUserはログインできない" do
    # Userを利用停止状態にする
    @user.update!(active: false)

    # 利用停止Userの正しい認証情報でログインを試みる
    post session_path, params: {
      email: @user.email,
      password: "password",
    }

    # sessionにUser IDが保存されていないことを確認する
    assert_nil session[:user_id]

    # ログイン画面が422で再表示されることを確認する
    assert_response :unprocessable_entity

    # ログイン失敗を知らせるメッセージが設定される
    assert flash[:alert].present?
  end
end
