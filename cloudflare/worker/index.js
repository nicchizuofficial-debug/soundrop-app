// SounDrop タイル配信 Worker（Cloudflare Workers + R2 + PMTiles）
//
// R2 に置いた basemap PMTiles から XYZ タイルを返す。
//   ベクター: /{z}/{x}/{y}.mvt （MapLibre等で描画／推奨・軽量）
//   ラスター: /{z}/{x}/{y}.png （ラスターPMTilesの場合のみ）
//
// 料金: R2は転送(egress)無料・保存$0.015/GB月。WorkerとCDNキャッシュでほぼ定額。
// デプロイ: cloudflare/worker で `npm i` → `npx wrangler deploy`

import { PMTiles, Source } from 'pmtiles';

/// R2 をデータ源にする PMTiles Source。
class R2Source {
  constructor(env) {
    this.env = env;
    this.key = env.PMTILES_KEY || 'basemap.pmtiles';
  }
  getKey() {
    return this.key;
  }
  async getBytes(offset, length) {
    const obj = await this.env.BUCKET.get(this.key, {
      range: { offset, length },
    });
    if (!obj) throw new Error('PMTiles not found in R2: ' + this.key);
    const data = await obj.arrayBuffer();
    return { data };
  }
}

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET,HEAD,OPTIONS',
};

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS });
    }
    const url = new URL(request.url);
    const m = url.pathname.match(/^\/(\d+)\/(\d+)\/(\d+)\.(mvt|pbf|png)$/);
    if (!m) {
      return new Response('Usage: /{z}/{x}/{y}.mvt', { status: 404 });
    }
    const [, zs, xs, ys, ext] = m;
    const z = +zs, x = +xs, y = +ys;

    // CDN キャッシュ（同一タイルの再取得を Worker/R2 まで来させない）。
    const cache = caches.default;
    const cached = await cache.match(request);
    if (cached) return cached;

    const p = new PMTiles(new R2Source(env));
    const tile = await p.getZxy(z, x, y);
    if (!tile || !tile.data) {
      return new Response(null, { status: 204, headers: CORS });
    }

    const contentType =
      ext === 'png' ? 'image/png' : 'application/x-protobuf';
    const resp = new Response(tile.data, {
      headers: {
        'content-type': contentType,
        'cache-control': 'public, max-age=86400',
        ...CORS,
      },
    });
    ctx.waitUntil(cache.put(request, resp.clone()));
    return resp;
  },
};
