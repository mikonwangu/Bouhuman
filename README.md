# Bouhuman

棒人間の連続戦闘アクション（Godot 4 / Web 向け骨格）。

## 要件

プロジェクト要件は Context の要件定義書に従う（戦闘ループ、武器／必殺カタログ、報酬、クリア30勝など）。

## 必要環境

- Godot **4.3+**（GL Compatibility / Web エクスポート想定）

## 遊び方（骨格）

1. **Play** → キャラ3種（パワー／スピード／バランス）を選択
2. 戦闘前に武器装備・必殺入れ替え → 戦闘
3. 操作: **A/D** 移動、**Space** ジャンプ（地上のみ・画面ボタン也可）、**Z/X/C** 弱／中／強、**V** 必殺
4. 勝利 → 報酬3択 → 次戦。10勝ごとにボス、30勝でクリア。敗北でゲームオーバー → タイトル

## Setting

- マスター音量 10段階
- ブラウザ／ウィンドウサイズ（小・中・大・フルスクリーン）
- 画質 低／中／大

## Web エクスポート

`export_presets.cfg` に **Web** プリセットあり。Godot から `builds/web/index.html` へエクスポート。

```text
Project → Export → Web → Export Project
```

## ディレクトリ

| パス | 内容 |
|------|------|
| `autoload/` | `GameState`, `SettingsManager` |
| `data/` | 武器・必殺・キャラタイプ定義 |
| `scenes/` | タイトル〜クリアまでの画面 |
| `scripts/` | 各画面・棒人間描画 |
