# Artifact 機能仕様

## 作成
### 実行できるUser
- ログイン済みUser

### 実行条件
- title 必須
- review_deadline 必須
- approver 必須
- ReviewerとApproverには、同じユーザーを選択できない
- CreatorはReviewer・Approverになれない

### 成功時
- Artifactが保存される
- Artifactにapprover・reviewerとして選択したUserを保存できる
- 成果物が作成された旨のflashメッセージが表示される
- Artifact詳細ページに遷移する
- ステータスがdraftになる

### 失敗時
#### ログインUser + 実行条件が満たされていない
→ バリデーションによる更新失敗
- 入力内容に応じたエラーメッセージが表示される
- Artifact作成画面が表示される

#### 未ログイン
→ 認証によるアクセス拒否
- ログイン画面へ遷移する
- ログインが必要である旨のエラーメッセージが表示される

---
## 更新
### 実行できるUser
- ArtifactのCreator

### 実行できる状態
- draft
- revision_required

### 実行条件
- 作成時と同じ

### 成功時
- Artifactが編集した内容で保存される
- approver・reviewerとして選択したUserを保存できる
- 成果物が更新された旨のflashメッセージが表示される
- Artifact詳細ページに遷移する

### 失敗時
#### Creator + draft + 実行条件が満たされていない
→ バリデーションによる更新失敗
- 入力内容に応じたエラーメッセージが表示される
- Artifact編集画面が表示される
- 422 Unprocessable Entity

#### Reviewer + 編集可能状態
- draft
- revision_required

→ 認可による操作拒否
- Creatorだけが編集・更新できるエラーメッセージが表示される
- Artifact詳細画面が表示される

#### Creator + 編集不可状態
- pending_review
- reviewing
- reviewed

→ 状態による操作拒否
- 編集できないエラーメッセージが表示される
- Artifact詳細画面が表示される

---
## 提出
### 実行できるUser
- ArtifactのCreator

### 実行できる状態
- draft

### 実行条件
- ファイルが添付されている

### 成功時
- 成果物が提出された旨のflashメッセージが表示される
- Artifact詳細ページに遷移する
- ステータスがpending_reviewになる

### 失敗時
#### Creator + draft + ファイル添付なし
→ バリデーションによる更新失敗
- ファイルが添付されていないエラーメッセージが表示される
- 成果物詳細画面が表示される

#### Reviewer + draft
→ 認可による操作拒否
- Creatorだけが提出できるエラーメッセージが表示される
- Artifact詳細画面が表示される

#### Creator + 提出不可状態
- pending_review
- reviewing
- revision_required
- reviewed

→ 状態による操作拒否
- 現在の状態ではArtifactを提出できない旨のエラーメッセージが表示される
- Artifact詳細画面が表示される

---
## 再提出
### 実行できるUser
- ArtifactのCreator

### 実行できる状態
- revision_required

### 成功時
- 成果物が再提出された旨のflashメッセージが表示される
- Artifact詳細ページに遷移する
- ステータスがpending_reviewになる
- roundが1増える

### 失敗時
#### Reviewer + revision_required
→ 認可による操作拒否
- Creatorだけが再提出できるエラーメッセージが表示される
- Artifact詳細画面が表示される

#### Creator + 再提出不可状態
- draft
- pending_review
- reviewing
- reviewed

→ 状態による操作拒否
- 現在の状態ではArtifactを再提出できない旨のエラーメッセージが表示される
- Artifact詳細画面が表示される

---
## 削除
### 実行できるUser
- ArtifactのCreator

### 実行できる状態
- draft

### 成功時
- 成果物が削除された旨のflashメッセージが表示される
- Artifact一覧ページに遷移する
- リダイレクト時のHTTPステータスコードとして 303 See Other を返す

### 失敗時
#### Reviewer + draft
→ 認可による操作拒否
- Creatorだけが削除できるエラーメッセージが表示される
- Artifact詳細画面が表示される

#### Creator + 削除不可状態
- pending_review
- reviewing
- revision_required
- reviewed

→ 状態による操作拒否
- 現在の状態ではArtifactを削除できない旨のエラーメッセージが表示される
- Artifact詳細画面が表示される
- リダイレクト時のHTTPステータスコードとして 303 See Other を返す

---
## 操作権限・状態一覧

| 操作 | User | draft | pending_review | reviewing | revision_required | reviewed |
| --- | --- | --- | --- | --- | --- | --- |
| 編集 | Creator | ○ | × | × | ○ | × |
| 提出 | Creator | ○ | × | × | × | × |
| 再提出 | Creator | × | × | × | ○ | × |
| 削除 | Creator | ○ | × | × | × | × |
| 編集 | Reviewer・Approver | × | × | × | × | × |
| 提出 | Reviewer・Approver | × | × | × | × | × |
| 再提出 | Reviewer・Approver | × | × | × | × | × |
| 削除 | Reviewer・Approver | × | × | × | × | × |

Artifact作成
→ ログイン済みUserなら可能
→ 作成後はdraft

---
## Review

### Review作成可能なUser
- Reviewerとして選択されたUser
- Approverとして選択されたUser

### Review作成不可のUser
- Creator
- Reviewer・Approverどちらにも選択されていないUser

### Review作成後の状態遷移

#### 最初のReviewが作成された場合
- pending_review → reviewing

#### Reviewer全員とApproverのReviewが完了した場合
- Approverがok → reviewed
- Approverがuneasyまたはng → revision_required
