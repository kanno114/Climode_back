# Climode Backend

Climode のバックエンド API。Rails 7.2（API モード）を使用した RESTful API です。

## 技術スタック

- **Ruby**: 3.3.6
- **Rails**: 7.2.2.2（API モード）
- **PostgreSQL**: 15
- **主要 Gem**:
  - `bcrypt` - パスワードハッシュ化
  - `rack-cors` - CORS 対応
  - `dentaku` - 論理式評価
  - `jwt` - JWT 認証
  - `httparty` - HTTP 通信
  - `kaminari` - ページネーション
  - `web-push` - プッシュ通知
  - `whenever` - 定期ジョブスケジューリング
  - `sentry-ruby`, `sentry-rails` - エラーモニタリング
  - `resend` - メール送信
- **セキュリティ**: `brakeman`（静的解析）
- **テスト**: rspec-rails, factory_bot_rails, faker, shoulda-matchers, database_cleaner, json_spec
- **デプロイ**: Render

## 開発環境の起動

### Docker Compose を使用（推奨）

プロジェクトルートの`docker-compose.yml`を使用して起動します：

```bash
# プロジェクトルートから
docker-compose up back db
```

バックエンド API は `http://localhost:3001` で起動します。

### ローカルで直接起動

```bash
# 依存Gemのインストール
bundle install

# データベースのセットアップ
rails db:create
rails db:migrate
rails db:seed

# 開発サーバーの起動
rails server
```

開発サーバーは `http://localhost:3000` で起動します。

## API エンドポイント概要

### 認証

- `POST /api/v1/signin` - サインイン
- `POST /api/v1/signup` - サインアップ
- `POST /api/v1/oauth_register` - OAuth 登録
- `GET /api/v1/validate_token` - トークン検証
- `POST /api/v1/password_resets` - パスワードリセット要求
- `PATCH /api/v1/password_resets/:id` - パスワードリセット実行
- `POST /api/v1/email_confirmation` - メール確認送信
- `PATCH /api/v1/email_confirmation/:id` - メールアドレス確認

### ユーザー

- `GET /api/v1/users/:id` - ユーザー情報取得
- `PATCH /api/v1/users/:id` - ユーザー情報更新
- `GET /api/v1/users/default_prefecture` - デフォルト都道府県取得

### 日次ログ

- `GET /api/v1/daily_logs` - 日次ログ一覧
- `GET /api/v1/daily_logs/:id` - 日次ログ詳細
- `GET /api/v1/daily_logs/date/:date` - 日付指定で取得
- `GET /api/v1/daily_logs/date_range_30days` - 30 日間のログ取得
- `GET /api/v1/daily_logs/by_month` - 月別ログ取得
- `POST /api/v1/daily_logs/morning` - 朝の入力
- `POST /api/v1/daily_logs/evening` - 夜の入力
- `PATCH /api/v1/daily_logs/:id/self_score` - 自己スコア更新

### 都道府県

- `GET /api/v1/prefectures` - 都道府県一覧
- `GET /api/v1/prefectures/:id` - 都道府県詳細

### 提案

- `GET /api/v1/suggestions` - 行動提案一覧
  - クエリパラメータ: `date`, `time` (morning/evening)

### 関心トピック

- `GET /api/v1/concern_topics` - 関心トピック一覧
- `GET /api/v1/user_concern_topics` - ユーザーの関心トピック取得
- `PATCH /api/v1/user_concern_topics` - ユーザーの関心トピック更新

### 天気予報

- `GET /api/v1/forecast` - 24 時間天気予報

### レポート

- `GET /api/v1/reports/weekly` - 週次レポート
  - クエリパラメータ: `start` (YYYY-MM-DD)

### プッシュ通知

- `POST /api/v1/push_subscriptions` - プッシュ通知購読登録
- `DELETE /api/v1/push_subscriptions/by_endpoint` - 購読解除

### その他

- `GET /up` - ヘルスチェック
- `GET /service-worker` - PWA Service Worker
- `GET /manifest` - PWA Manifest

## 主要な機能・サービス構成

### サービス層

- `Auth::JwtService` - JWT トークン管理
- `Suggestion::SuggestionEngine` - 行動提案生成
- `Suggestion::RuleEngine` / `RuleRegistry` - ルール評価
- `Suggestion::SuggestionPersistence` - 提案スナップショット永続化
- `Weather::WeatherDataService` - 気象データ取得
- `Weather::WeatherSnapshotService` - 気象スナップショット保存
- `Reports::WeeklyReportService` - 週次レポート生成
- `Reports::WeeklyAnalysisService` - 週次分析
- `Reports::CorrelationAnalyzer` - 相関分析
- `PushNotificationService` - プッシュ通知送信

### ジョブ

- `MorningSuggestionJob` - 提案事前計算ジョブ（毎朝 7:30）
- `MorningNotificationJob` - 朝のシグナル通知ジョブ（毎朝 8:00）
- `DailyReminderJob` - 夜のリマインダージョブ（毎晩 20:00）

### モデル

- `User` - ユーザー
- `UserIdentity` - OAuth ID 管理
- `DailyLog` - 日次ログ
- `DailyLogSuggestion` - 日次ログと提案の関連付け
- `SuggestionRule` - 提案ルール定義
- `SuggestionSnapshot` - 提案スナップショット
- `SuggestionFeedback` - 提案フィードバック
- `WeatherSnapshot` - 気象スナップショット
- `Prefecture` - 都道府県
- `ConcernTopic` - 関心トピック
- `UserConcernTopic` - ユーザー関心トピック
- `PushSubscription` - プッシュ通知購読

## テスト

```bash
# テスト実行
bundle exec rspec

# 特定のファイルのみ実行
bundle exec rspec spec/models/user_spec.rb

# カバレッジ
COVERAGE=true bundle exec rspec
```

## データベース

```bash
# マイグレーション実行
rails db:migrate

# ロールバック
rails db:rollback

# シードデータ投入
rails db:seed

# データベースリセット
rails db:reset
```

## 定期ジョブ

`whenever`を使用して定期ジョブをスケジューリングしています。

```bash
# スケジュール確認
bundle exec whenever

# スケジュール更新（本番環境）
bundle exec whenever --update-crontab
```

主なジョブ:

- 毎朝: シグナル判定・通知送信
- 毎夜: リマインダー送信

## デプロイ

Render にデプロイされています。

## 開発時の注意事項

- API モードのため、ビューは使用しません（PWA 関連を除く）
- 認証は JWT トークンベースで実装
- CORS は`rack-cors`で設定
- 環境変数は`.env`ファイルで管理（`.env.example`を参照）
- サービス層にビジネスロジックを集約（Fat Controller を避ける）
