class AddActiveToUsers < ActiveRecord::Migration[7.1]
  def change
    # 退職者や利用停止ユーザーも履歴として残す
    add_column :users, :active, :boolean,
                null: false,
                default: true
  end
end
