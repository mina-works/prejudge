require "test_helper"

class ApplicationLayoutTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:creator)
  end

  test "ログイン中はログアウト導線を表示する" do
    log_in_as(@user)
    get artifacts_path

    assert_response :success
    assert_select "form[action=?][method=post]", session_path do
      assert_select "input[name=_method][value=delete]", count: 1
      assert_select "button", text: I18n.t("common.logout"), count: 1
    end
  end

  test "未ログイン時はログアウト導線を表示しない" do
    get new_session_path

    assert_response :success
    assert_select "form[action=?] input[name=_method][value=delete]",
                  session_path,
                  count: 0
    assert_select "button", text: I18n.t("common.logout"), count: 0
  end
end
