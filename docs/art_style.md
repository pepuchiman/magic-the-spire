# Magic The Spire アートスタイルガイド

> このファイルは docs/ に置き、Claude Code がイラスト用プロンプト作成・素材の組み込みを行うときの基準にする。
> 【要決定】と書かれた箇所は、試し描きの結果を見て書き換えること。

---

## 1. コンセプト

- **テーマ**：塔を登る若い魔法使いの冒険。神秘的だが暗すぎない、少し絵本寄りのダークファンタジー
- **画風（既定案）**：手描き風の厚塗り（ペインタリー）、輪郭線はやや太め、明暗のコントラストはっきり
- **スマホの小さい画面でも読める絵**：主題は1つ、シルエットで何かわかる、背景はシンプル
- 画風：**A. 厚塗りファンタジーに決定**（2026-10-15 の試し描きで決定。B は A との違いが小さく、C はこのモデルでは描けなかった）

## 2. カラーパレット

| 用途 | 色 | 備考 |
|---|---|---|
| ベース（背景・UI地） | 深い藍 `#1E2340` / 夜紫 `#2E2550` | 全体のトーン |
| アクセント | 魔法の金 `#E8B84A` | レア度・強調 |
| 攻撃カード | 炎の朱 `#D9553B` | 種別「攻撃」 |
| 付与カード | 氷の青 `#4AA3D9` | 種別「付与」（アーマー・回復・状態効果など） |
| 召喚カード | 森の緑 `#5BB57A` | 種別「召喚」 |
| 空間カード | 魔法の金 `#E8B84A` | 種別「空間」 |
| 呪い・状態異常 | 毒の紫 `#8E4AD9` | 状態効果（毒・呪いなど）の差し色 |

- 1枚のイラストで使う主要色は3色まで。カード種別の色を必ず1つ含める
- カード種別はゲームの種別（召喚・攻撃・付与・空間）に合わせる。弱体・毒などを与える付与カードは、氷の青を主に、毒の紫を差し色にする
- ゲーム内の色は `ui/ui_palette.gd` がこの表に合わせている（色を変える時は両方を直す）

## 3. 素材一覧とサイズ

縦画面を前提とする。ゲームの基準解像度は 720×1280（CLAUDE.md）。素材は 1080×1920 相当の大きさで仕上げ、ゲーム内で縮小して使う（縦横比は同じ 9:16 なので問題ない）。
SD1.5 は 512px 前後で学習されているため、**小さく生成 → Hires fix / アップスケールで拡大 → 組み込み時に縮小**の流れにする。
（最初から大きいサイズで生成すると、人物や物体が二重・三重に出る崩れが起きやすい）

| 素材 | 生成サイズ（SD1.5） | 仕上げサイズ | ゲーム内表示 | 保存先 |
|---|---|---|---|---|
| カードイラスト | 512×512 | 1024×1024（2倍）→ 組み込み時に 512×512 | カードの絵の枠（約5:4の横長。正方形の絵は上下が1割ずつ切れる。下端には種別の帯、右上には触媒の印が重なる） | `assets/cards/` |
| 敵キャラ（正面向き） | 512×768（縦長） | 1024×1536（2倍） | 画面右上、背景透過 | `assets/enemies/` |
| 主人公（正面・背中の2枚） | 512×768 | 1024×1536（2倍） | 正面＝主人公選択など、背中＝戦闘の画面左下。背景透過 | `assets/player/` |
| 自分のクリーチャー（背中向き） | 512×768 | 1024×1536（2倍） | 戦闘の主人公の斜め奥、背景透過 | `assets/creatures/` |
| 戦闘背景 | 512×912（≒9:16） | 1080×1920（約2.1倍） | 全画面 | `assets/backgrounds/` |
| アイコン（状態効果・マップ・装備） | 512×512 | 256×256に縮小 | 小アイコン | `assets/icons/` |

- 縦横は 8 の倍数にする（SD1.5 の制約）
- 戦闘背景で崩れが出る場合は 512×768 で生成し、拡大後に左右をトリミングして 9:16 に合わせる
- PCVR版を出す場合は、カード・背景は最低 2048px 相当まで高解像度化（仕上げ後にさらにアップスケーラーで2倍）
- 戦闘画面の向き：敵と敵のクリーチャーは正面向き、主人公と自分のクリーチャーは背中向き（ポケモンのような配置）
- ファイル名は英小文字のスネークケース。`<ID>` はデータ（data/ の .tres）のID。この名前にすると、ツールでデータに自動で結び付けられる（6章）

| 素材 | ファイル名 |
|---|---|
| カード | `card_<ID>.png`（例：`card_fireball.png`） |
| 主人公 | `hero_<ID>_front.png`、`hero_<ID>_back.png` |
| 自分のクリーチャー | `creature_<ID>_back.png` |
| 敵 | `enemy_<ID>.png` |
| 戦闘背景 | `bg_<ダンジョンID>.png` |
| 装備 | `equip_<ID>.png` |
| 状態効果・マップのマス・装備の種類 | `status_<種類>.png`、`map_<種類>.png`、`equip_type_<種類>.png`（例：`status_poison.png`、`map_rest.png`） |

- 拡張子は png・webp・jpg のどれでもよい（背景を透過する素材は png か webp）

## 4. プロンプト雛形（ComfyUI / SD1.5 向け）

> SD1.5 は先頭の単語ほど強く効く。トリガーワードと画風指定は必ず先頭に置く。
> `(言葉:1.3)` のように書くと、その言葉を強める（1.0 が普通。1.2〜1.4 程度で使う）。
> 2026-10-15 の試し描きの結果を反映済み（下の「試し描きで分かったこと」）。

### 共通ポジティブ（全素材の先頭に付ける）
```
zrpgstyle, masterpiece, best quality,
fantasy game illustration, painterly style, thick outlines, high contrast lighting,
single clear subject
```
- 色づかい・背景の言葉は、素材ごとの雛形で足す（キャラクターに「藍と紫」を入れると、背景が灰色にならないため）

### 共通ネガティブ
```
worst quality, low quality, normal quality, bad anatomy,
text, letters, watermark, signature, logo, frame, border, card frame,
blurry, lowres, jpeg artifacts, extra fingers, deformed hands,
cluttered background, multiple subjects, photo, realistic,
nsfw, nudity, bare skin, cleavage, bare legs
```
- 人を描かない素材（敵・クリーチャー・カード・アイコン・背景）は、さらに `human, girl, woman, man, person, face` を足す

### カードイラスト
```
[共通ポジティブ], deep indigo background, magical glow, centered composition, subject in the center, empty margins at top and bottom,
(close-up of {カードの主役を英語で}:1.2), {カードの内容を英語で1文}, ({種別カラー} dominant color:1.3),
spell effect, dynamic angle, icon-like readability
```
- 主役は「魔法・物・生き物」にして、人物を描かない（カードの絵の枠は横長で、中央が切り取られるため。人物だと顔と胴しか見えない）
- 主役は中央に置き、上下の端（各1割）と右上・下端に大事なものを置かない（ゲームでは上下が切れ、右上に触媒の印、下端に種別の帯が重なるため）。プロンプトに `subject in the center, empty margins at top and bottom` を入れる
- 種別カラー：攻撃=`crimson red`、付与=`icy blue`、召喚=`emerald green`、空間=`golden`（状態効果の差し色=`toxic violet`）
- 例（火球）：`... (close-up of a blazing fireball:1.2), a blazing fireball flying forward with a fiery trail, (crimson red dominant color:1.3), ...`

### 敵キャラ（正面向き）
```
[共通ポジティブ], (plain flat gray background:1.2), simple background, solo, no humans,
full body {敵の説明}, front view, facing the viewer, menacing monster, charming creature design
```
- `cute` は使わない（人の女の子が出やすくなるため）
→ 背景は ComfyUI の Remove Background（BiRefNet）で、生成と同時に消す（tools/comfy_generate.gd が敵・主人公・クリーチャーで自動で行う。5章「背景の切り抜き」）
- スライムなど半透明になりやすいものは `solid opaque body, no bubble` を足す（泡や半透明の部分は切り抜きが不安定なため）

### 主人公・自分のクリーチャー
正面向き（主人公のみ。主人公選択などで使う）
```
[共通ポジティブ], (plain flat gray background:1.2), simple background, solo,
full body {主人公の説明}, front view, facing the viewer
```
背中向き（戦闘で使う。主人公と自分のクリーチャー）
```
[共通ポジティブ], (plain flat gray background:1.2), simple background, solo,
full body {主人公・クリーチャーの説明}, seen from behind, back view, facing away from the viewer
```
- クリーチャーは `no humans` も足す
- 体・服の色は `(red pointed wizard hat:1.3)`、`(green translucent slime:1.3)` のように強める（灰色の背景の指定で、体まで灰色になりやすいため。敵も同じ）
→ 正面と背中で、服装・色・持ち物をそろえる（同じキャラクターに見えるように）

### アイコン（状態効果・マップのマス・装備）
```
[共通ポジティブ], deep indigo background, magical glow, centered composition,
game icon of {アイコンの内容}, ({色} dominant color:1.3), simple shape, bold silhouette
```

### 戦闘背景
```
[共通ポジティブ], deep indigo and purple color scheme, magical glow,
interior of an ancient magic tower, {階層の雰囲気},
vertical composition, empty center area, no characters, soft depth of field
```
→ 中央を空けるのは、敵とカードが重なっても見やすくするため

### 試し描きで分かったこと（2026-10-15、A-Zovya RPG V4-VAE）
- 画風は A（厚塗り）が狙いどおり。B（フラット）は A との違いが小さい。C（ドット絵風）はこのモデルでは描けない（ドット絵用の LoRA が必要）
- 主人公の背中向きは、そのまま描ける
- 共通ポジティブに「deep indigo and purple color scheme」を入れると、全部が紫寄りになり、種別の色が弱くなる・背景が灰色にならない
- 「cute」を入れた敵（スライム）は、人の女の子が主役になり、露出も出た → ネガティブで人と露出を防ぐ
- カードは何もしないと魔法使いの上半身が主役になる → 魔法・物を主役にする（2回目の試し描きで、火球・盾・狼とも主役が分かる絵になった）
- 灰色の背景を `:1.4` で強めると、体・服まで灰色になる → 背景は `:1.2` にして、体の色を強める
- 灰色の背景は、生成すると中央が少し明るいグラデーションになる。tools/remove_gray_bg.gd は、少しずつ変わる灰色をたどって抜けるようにしてある（2026-10-16 からは BiRefNet で消す。灰色抜きは BiRefNet が使えない時の予備）
- BiRefNet で消すと、輪郭がきれいで光のにじみも残らない。灰色抜きでは、炎のまわりの光や泡の縁が残った

## 5. 生成設定（SD1.5・2070 SUPER／VRAM 8GB 想定）

### モデル
| 区分 | モデル | トリガー | 備考 |
|---|---|---|---|
| 本命 | A-Zovya RPG Artist Tools **V4-VAE**（比較用に V3+VAE） | `zrpgstyle` | RPG・厚塗り向き。VAE内蔵版なのでVAE指定不要 |
| 次点 | DreamShaper 8 | なし | 汎用。使う場合は共通ポジティブから `zrpgstyle` を外す |

- 採用したモデル：A-Zovya RPG Artist Tools V4-VAE（aZovyaRPGArtistTools_v4VAE.safetensors）。2026-10-15 の試し描きで決定
- **広告収益化を予定しているため、Civitai のモデルページでライセンス（CreativeML Open RAIL-M ＋ Addendum）の「画像の販売・商用利用」可否を確認し、確認日をここに記録する**：A-Zovya RPG Artist Tools V4-VAE は商用利用可（利用者が 2026-10-15 に確認）。anylora は未確認のため使わない
- 非営利ライセンス（CC BY-NC 系など）や「画像販売禁止」のモデル・LoRA は使わない

### 基本設定（txt2img）
| 項目 | 値 |
|---|---|
| サンプラー | DPM++ 2M Karras |
| ステップ | 25〜30 |
| CFG | 6〜7 |
| Clip Skip | 1 |
| 生成サイズ | 3章の表の「生成サイズ」 |
| バッチ | 4枚ずつ生成して選ぶ |

### 拡大（Hires fix 相当の2段階）
1. 1段目：上記設定で 512px 台の画像を生成
2. 2段目：アップスケールモデル（ESRGAN 系など）で2倍に拡大 → 同じモデルで img2img
   - denoise 0.35〜0.45（上げると描き込みが増えるが、構図が崩れやすい）
   - ステップ 15〜20
3. 気に入った構図が出たら、seed を固定して2段目だけ調整する
- アップスケールモデルも商用利用可のライセンスか確認する

### 背景の切り抜き（敵・主人公・クリーチャー）
| 項目 | 内容 |
|---|---|
| 方法 | ComfyUI 標準の Remove Background ノード（txt2img_hires_bg.json の最後で、背景を消して透明つきの画像にする） |
| モデル | BiRefNet（`birefnet.safetensors`、Hugging Face の Comfy-Org/BiRefNet。`ComfyUI/models/background_removal/` に置く） |
| ライセンス | MIT（商用利用可。利用者が 2026-10-16 に確認） |
| 予備 | BiRefNet が使えない時は tools/remove_gray_bg.gd（灰色の背景を色でたどって抜く。光や半透明の部分は残りやすい） |

- 背景を消した絵は、`tools/resize_image.gd` の `trim=true` で透明な余白を切り落としてから縮小し、assets/ に置く

### その他
- 画風固定：同じモデル・同じ共通プロンプトを使い回す。慣れたら画風LoRA（SD1.5用）で統一
- 気に入った1枚の **seed とプロンプトを下の生成ログに記録**しておく
- VRAM：SD1.5 は 8GB で余裕がある。通常起動でよい（不足時のみ `--lowvram`）

## 6. Claude Code への作業ルール

- 新しいカード・主人公・クリーチャー・敵・ダンジョン・装備・状態効果などをデータに追加したら、このガイドの雛形に従って **英語プロンプトを `prompts/` の CSV に追記**する（列：`id, prompt, negative, size`）
  - ファイル：`cards.csv`、`heroes.csv`、`creatures.csv`、`enemies.csv`、`backgrounds.csv`、`icons.csv`
  - `id` は保存する画像のファイル名（拡張子なし。3章の名前の決まり）。`prompt` は共通ポジティブを含めた完成形
  - `prompts/` には `.gdignore` を置いている（Godot が CSV を翻訳ファイルとして読み込まないように）
- 画像を `assets/` に3章の名前で置いたら、次の順に実行してデータに結び付ける（絵の項目だけが変わる）
  1. `--headless --import`（画像を Godot に読み込ませる）
  2. `--headless -s tools/link_art.gd`（ファイル名でデータの絵の項目に結び付ける）
  3. 検証（`tools/validate_data.gd`）
- 画像がまだ無い所は、図形で仮表示する（カード＝種別カラーと記号、キャラクター＝種族ごとの形、アイコン＝記号、戦闘背景＝ダンジョンの2色のグラデーション）
- 後処理はスクリプト化して `tools/` に置いている：背景の切り抜き（comfy_generate.gd の bg=、予備は remove_gray_bg.gd）、縮小と余白の切り落とし（resize_image.gd）。Godot の読み込み設定は初期設定のまま
- 素材を差し替えてもゲームが壊れないよう、画像パスはデータ側（カード・主人公・クリーチャー・敵・装備・ダンジョンの絵の項目、アイコンは `data/config/icon_set.tres`）で管理する

## 7. 品質チェックリスト

- [ ] スマホ実寸（カード幅 約200px）に縮小しても何の絵かわかる
- [ ] 文字・透かし・余計な枠が入っていない
- [ ] 種別カラーが一目でわかる
- [ ] 他のカードと並べて画風が浮いていない
- [ ] ライセンス・生成ログを記録した

## 8. 生成ログ

| ファイル | モデル | seed | 生成サイズ / denoise | 備考 |
|---|---|---|---|---|
| （例）card_fireball.png | A-Zovya V4-VAE | 123456 | 512×512 / 0.4 | 基準絵として採用 |
| card_fireball.png | A-Zovya V4-VAE | 3000 | 512×512 / 0.4 | 2026-10-15 試し描き2回目で採用（画風A）。512px に縮小 |
| card_guard.png | A-Zovya V4-VAE | 3000 | 512×512 / 0.4 | 2026-10-15 試し描き2回目で採用（画風A）。512px に縮小 |
| card_summon_wolf.png | A-Zovya V4-VAE | 3003 | 512×512 / 0.4 | 2026-10-15 試し描き2回目で採用（画風A）。512px に縮小 |
| enemy_slime.png | A-Zovya V4-VAE | 5001 | 512×768 / 0.4 | 2026-10-16 BiRefNet で背景を消して採用（不透明な体のプロンプト）。高さ640に縮小 |
| hero_flame_mage_back.png | A-Zovya V4-VAE | 4001 | 512×768 / 0.4 | 2026-10-15 試し描き3回目で採用。2026-10-16 に同じ seed で作り直し、BiRefNet で背景を消した。高さ768に縮小 |
