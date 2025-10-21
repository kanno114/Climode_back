#!/bin/bash
set -e

# PostgreSQLの待機
until pg_isready -h db -p 5432 -U postgres; do
  echo 'Waiting for PostgreSQL...'
  sleep 2
done
echo 'PostgreSQL is ready!'

# データベースの作成とマイグレーション
bundle exec rails db:create db:migrate

# cronデーモンの開始
service cron start

# wheneverでcrontabを設定
bundle exec whenever --update-crontab

echo "Cron jobs configured successfully"

# 引数が渡された場合はそれを実行、そうでなければデフォルトコマンドを実行
if [ $# -eq 0 ]; then
  exec bundle exec rails server -b 0.0.0.0 -p 3000
else
  exec "$@"
fi
