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
end
