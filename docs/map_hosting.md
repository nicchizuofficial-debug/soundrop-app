# 地図タイルの自前配信（全国〜世界規模・低コスト）

全国/世界のユーザー向けに、**ユーザー数で料金が跳ねない**地図配信の構成。
結論：**Protomaps（PMTiles）を Cloudflare R2 に置き、Worker で XYZ タイルとして配信**。

## なぜこれか
- ホスト型（Google/Mapbox/MapTiler等）は**リクエスト課金**なので大規模化で高額化しやすい。
- PMTiles はタイル群を**1ファイル**にまとめ、必要部分だけ range リクエストで取得。
- **Cloudflare R2 は egress（転送）無料**。ストレージは $0.015/GB・月。
  - 例: planet ベースマップ PMTiles ≈ 100GB → **ストレージ約$1.5/月、転送$0**。
  - 日本のみ抽出なら数百MB〜数GBでさらに安い。
- Worker は無料枠 10万req/日、超えても $5/月で 1,000万req/日。**ほぼ定額でスケール**。

## 構成
```
[アプリ flutter_map] --XYZ--> [Cloudflare Worker(pmtiles)] --range--> [R2: basemap.pmtiles]
```

## 手順（実コマンド）

このリポジトリ同梱の Worker: [cloudflare/worker/](../cloudflare/worker/)
ダークスタイル: [cloudflare/style-dark.json](../cloudflare/style-dark.json)

### 1. PMTiles を作る（まず日本だけ → あとで世界）
**最短（既製を使う）**：Protomaps の planet basemap（日次ビルドの `.pmtiles`）をDL。
**自作（planetiler・推奨, Java 21必要）**：
```bash
# 日本のみ（Geofabrikの日本抽出を自動DLしてベクターPMTiles生成。数百MB〜）
curl -L -o planetiler.jar \
  https://github.com/onthegomap/planetiler/releases/latest/download/planetiler.jar
java -Xmx6g -jar planetiler.jar --download --area=japan --output=japan.pmtiles

# 世界（ディスク/RAM要・時間かかる。最初は日本で十分）
# java -Xmx16g -jar planetiler.jar --download --area=planet --output=planet.pmtiles
```

### 2. R2 にアップロード
```bash
cd cloudflare/worker
npm i
npx wrangler r2 bucket create sounddrop-tiles
npx wrangler r2 object put sounddrop-tiles/japan.pmtiles --file=../../japan.pmtiles
```

### 3. Worker をデプロイ
```bash
# wrangler.toml の PMTILES_KEY は "japan.pmtiles"
npx wrangler deploy
# → https://sounddrop-tiles.<account>.workers.dev/{z}/{x}/{y}.mvt が公開される
#   （独自ドメインを割り当てると https://tiles.yourapp.com/... に）
```
動作確認: ブラウザで `.../14/14552/6451.mvt` がDLできればOK。

### 4. アプリから使う
**ラスターPMTiles の場合**（`.png`）は flutter_map のまま、URLを差すだけ:
```bash
flutter run --dart-define=TILE_URL=https://tiles.yourapp.com/{z}/{x}/{y}.png \
            --dart-define=TILE_ATTRIBUTION="© OpenStreetMap"
```
**ベクターPMTiles の場合**（推奨・`.mvt`）は描画に MapLibre を使う:
- `cloudflare/style-dark.json` の `tiles` の URL を自分の Worker（`/{z}/{x}/{y}.mvt`）に書き換え、
  どこか（R2/GitHub Pages等）に style.json を公開。
- Flutter は `maplibre_gl`（または `vector_map_tiles` + flutter_map）で
  `styleString: 'https://.../style-dark.json'` を指定して描画。
- デモ(HTML)は MapLibre GL JS で同 style を読み込む。

> まずは **日本のベクターPMTiles + Worker + MapLibreダークスタイル** で開始し、
> 世界展開時に `planet.pmtiles` に差し替え（`PMTILES_KEY` を変えて再デプロイ）するのが低リスク。

## ラスター vs ベクター
- **ラスター（{z}/{x}/{y}.png）**：flutter_map の `TileLayer` でそのまま表示。実装が最も簡単。
- **ベクター（.mvt）**：`maplibre`/`vector_map_tiles` で描画。**ダークスタイルを自由に作れて軽量**。
  ブランドの紺テーマに完全一致させたいならこちら（実装コストは上がる）。

## 推奨ロードマップ（SounDrop）
1. **ローンチ初期**：MapTiler/Stadia 無料枠（キーを `--dart-define` で注入）。実装済み・即運用可。
2. **全国でユーザー増**：本書の **Protomaps + R2 + Worker** に移行。`TILE_URL` を差すだけ。
   料金はほぼ定額（月 数ドル）。
3. **世界展開＆ブランド徹底**：ベクター（MapLibre）＋独自ダークスタイルへ。

## 注意
- どの方式でも **© OpenStreetMap の帰属表示は必須**（`TILE_ATTRIBUTION` で設定）。
- 完全$0は保証されない（R2ストレージ/Worker超過分は微課金）。ただし**リクエスト課金型より桁違いに安く・予測可能**。
