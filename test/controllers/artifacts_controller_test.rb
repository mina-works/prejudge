require "test_helper"

class ArtifactsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get artifacts_show_url
    assert_response :success
  end

  test "should get create" do
    get artifacts_create_url
    assert_response :success
  end
end
