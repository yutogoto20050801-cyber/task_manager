課題管理アプリ
大学生向けにつくった、締め切り管理アプリです。

課題の追加・編集・削除ができ、締め切り前日に通知が届くため、提出忘れを防げます。

主な機能
・課題の追加・編集・削除
・スワイプで削除
・完了チェック
・締め切り前日のローカル通知
・検索機能（タイトル/日付）
・SQLiteによるデータ保存
・iOS/Andoroid対応

使用技術
・Flutter
・Dart
・SQLite
・flutter_local_notifications
・timezone
・Material Design

<img width="1206" height="2622" alt="simulator_screenshot_346D9141-B7A3-4EF3-AE39-63A55F555584" src="https://github.com/user-attachments/assets/240d8663-95b6-4ff0-8bd3-7462e4dea770" />
<img width="1206" height="2622" alt="simulator_screenshot_07DBE27F-D827-4A94-8138-4251D26D9C62" src="https://github.com/user-attachments/assets/51ebb6fa-c143-43f1-a30d-8c1f30738a9a" />
<img width="1206" height="2622" alt="simulator_screenshot_57C9CB7B-51F2-42CB-96E2-4A7D81B7C138" src="https://github.com/user-attachments/assets/900302cc-1b88-4784-96f2-0f5a47356b4f" />
<img width="1206" height="2622" alt="simulator_screenshot_6F88FC8D-7184-488A-B13C-67C01A12EB13" src="https://github.com/user-attachments/assets/066e9ec0-f5af-49b9-a338-6f7dca1cfba8" />
<img width="1206" height="2622" alt="simulator_screenshot_064E1B38-CABC-40AF-8C43-54A3642D24BE" src="https://github.com/user-attachments/assets/e1d3c98c-91a1-4843-bff9-54127c5e3e87" />
<img width="1206" height="2622" alt="simulator_screenshot_A8471760-5B01-4136-9731-AAA0B3DCB092" src="https://github.com/user-attachments/assets/071b622d-e53b-4ab5-ac0b-2f94771a60a1" />

工夫したポイント
・締め切り前日に自動で通知が届くようにした
・SQLiteを使ってアプリを閉じてもデータが残るようにした
・UIをシンプルでみやすく設計
・編集時に既存データが自動で入力されるようにした
・Disimissibleを使ってスワイプ削除を実装

苦労した点と解決方法
・通知の時刻がズレる問題
　→timezoneパッケージを導入して解決。
・SQLiteの更新が反映されない
　→setStateとDB更新の順番を調整
・UIが崩れる
　→Widgetを分割し、builfTaskCardを外に出して整理

 今後の改善案
 ・科目ごとに色分け
 ・ダークモード対応
 ・Firebase Authでログイン機能
 ・Rverpodで状態管理を整理
 ・提出物の写真添付機能

 プロジェクト構成
 lib/
 ├─ main.dart                ← アプリの起動・テーマ設定
 ├─ task_list_page.dart      ← 課題一覧画面
 ├─ add_task_page.dart       ← 課題追加画面
 └─ database_helper.dart     ← SQLite の処理


作者
名前：後藤優斗
大学3年/Flutter学習中
GitHub: https://github.com/yutogoto20050801-cyber 
(github.com in Bing)
