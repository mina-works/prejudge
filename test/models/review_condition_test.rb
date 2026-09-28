require "test_helper"

class ReviewConditionTest < ActiveSupport::TestCase
  setup do
    @review_condition = review_conditions(:draft_condition)
  end

  test "purposeがない場合はinvalid" do
    @review_condition.purpose = nil

    assert_not @review_condition.valid?
    assert_includes @review_condition.errors[:purpose], I18n.t("errors.messages.blank")
  end

  test "targetがない場合はinvalid" do
    @review_condition.target = nil

    assert_not @review_condition.valid?
    assert_includes @review_condition.errors[:target], I18n.t("errors.messages.blank")
  end

  test "toneがない場合はinvalid" do
    @review_condition.tone = nil

    assert_not @review_condition.valid?
    assert_includes @review_condition.errors[:tone], I18n.t("errors.messages.blank")
  end

  test "purposeとtargetとtoneがある場合はvalid" do
    assert_predicate @review_condition, :valid?
  end

  test "モデル名とValidationエラーを日本語で表示する" do
    @review_condition.assign_attributes(
      purpose: nil,
      target: nil,
      tone: nil
    )

    assert_equal "レビュー条件", ReviewCondition.model_name.human
    assert_equal "成果物", ReviewCondition.human_attribute_name(:artifact)
    assert_not @review_condition.valid?
    assert_equal(
      [
        "目的を入力してください",
        "対象を入力してください",
        "トーンを入力してください"
      ],
      @review_condition.errors.full_messages
    )
  end
end
