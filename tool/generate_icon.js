// SounDrop アプリアイコンPNG生成（依存ゼロ。Node標準のzlibのみ）。
//
// 共有アイコンの「四角内のモチーフ」= ダークネイビー背景＋ピンク→ブルーの
// グラデーションで描いた地図ピン×音声波形 を 1024x1024 で出力する。
//   - assets/icon/app_icon.png            : ネイビー背景入り（iOS/旧Android用）
//   - assets/icon/app_icon_foreground.png : 透過背景・セーフゾーン縮小（Adaptive前景）
//
// 実行: node tool/generate_icon.js

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const SIZE = 1024;
const NAVY = [29, 42, 76]; // #1D2A4C（アイコンPNGの紺と一致）
const PINK = [242, 168, 207]; // #F2A8CF
const BLUE = [143, 180, 232]; // #8FB4E8

function lerp(a, b, t) {
  return [
    Math.round(a[0] + (b[0] - a[0]) * t),
    Math.round(a[1] + (b[1] - a[1]) * t),
    Math.round(a[2] + (b[2] - a[2]) * t),
  ];
}

// 対角方向(左上→右下)のグラデーション色。
function gradAt(x, y) {
  const t = Math.max(0, Math.min(1, (x + y) / (2 * SIZE)));
  return lerp(PINK, BLUE, t);
}

function makeBuffer() {
  // RGBA
  return new Uint8ClampedArray(SIZE * SIZE * 4);
}

function setPx(buf, x, y, rgb, alpha) {
  if (x < 0 || y < 0 || x >= SIZE || y >= SIZE) return;
  const i = (y * SIZE + x) * 4;
  const a = Math.max(0, Math.min(1, alpha));
  const ia = 1 - a;
  buf[i] = rgb[0] * a + buf[i] * ia;
  buf[i + 1] = rgb[1] * a + buf[i + 1] * ia;
  buf[i + 2] = rgb[2] * a + buf[i + 2] * ia;
  buf[i + 3] = Math.max(buf[i + 3], Math.round(a * 255));
}

function fillBg(buf, rgb, alpha) {
  for (let y = 0; y < SIZE; y++)
    for (let x = 0; x < SIZE; x++) setPx(buf, x, y, rgb, alpha);
}

// 線分に沿って半径rの円を連続スタンプ（簡易アンチエイリアス付き）。
function stampStroke(buf, points, strokeW) {
  const r = strokeW / 2;
  for (let s = 0; s < points.length - 1; s++) {
    const [x0, y0] = points[s];
    const [x1, y1] = points[s + 1];
    const len = Math.hypot(x1 - x0, y1 - y0);
    const steps = Math.max(1, Math.ceil(len / 0.5));
    for (let k = 0; k <= steps; k++) {
      const t = k / steps;
      const cx = x0 + (x1 - x0) * t;
      const cy = y0 + (y1 - y0) * t;
      const minX = Math.floor(cx - r - 1), maxX = Math.ceil(cx + r + 1);
      const minY = Math.floor(cy - r - 1), maxY = Math.ceil(cy + r + 1);
      for (let py = minY; py <= maxY; py++) {
        for (let px = minX; px <= maxX; px++) {
          const d = Math.hypot(px + 0.5 - cx, py + 0.5 - cy);
          const cov = Math.max(0, Math.min(1, r - d + 0.5));
          if (cov > 0) setPx(buf, px, py, gradAt(px, py), cov);
        }
      }
    }
  }
}

// ピン(ティアドロップ)＋波形のポリラインを生成。
function buildMotif(scale, cx, cy) {
  const r = 246 * scale;
  const ccx = cx;
  const ccy = cy - 100 * scale; // 円の中心を少し上に
  const tip = [ccx, cy + 370 * scale];

  const pin = [];
  // 左カーブ（tip→円左）二次ベジェ
  const ctrlL = [ccx - r * 1.7, ccy + r * 0.9];
  const left = [ccx - r, ccy];
  for (let i = 0; i <= 40; i++) {
    const t = i / 40;
    const x = (1 - t) * (1 - t) * tip[0] + 2 * (1 - t) * t * ctrlL[0] + t * t * left[0];
    const y = (1 - t) * (1 - t) * tip[1] + 2 * (1 - t) * t * ctrlL[1] + t * t * left[1];
    pin.push([x, y]);
  }
  // 円の上半分（θ:180→0 で上を通る, y上向き）
  for (let i = 0; i <= 80; i++) {
    const th = Math.PI - (Math.PI * i) / 80;
    pin.push([ccx + r * Math.cos(th), ccy - r * Math.sin(th)]);
  }
  // 右カーブ（円右→tip）
  const right = [ccx + r, ccy];
  const ctrlR = [ccx + r * 1.7, ccy + r * 0.9];
  for (let i = 0; i <= 40; i++) {
    const t = i / 40;
    const x = (1 - t) * (1 - t) * right[0] + 2 * (1 - t) * t * ctrlR[0] + t * t * tip[0];
    const y = (1 - t) * (1 - t) * right[1] + 2 * (1 - t) * t * ctrlR[1] + t * t * tip[1];
    pin.push([x, y]);
  }

  // 内側の丸い枠（リング）。添付アイコン同様、ピン内に中空の円を描く。
  const rr = r * 0.72;
  const ring = [];
  for (let i = 0; i <= 120; i++) {
    const th = (Math.PI * 2 * i) / 120;
    ring.push([ccx + rr * Math.cos(th), ccy + rr * Math.sin(th)]);
  }

  // 波形（リングの中央を横切る声紋）。中央が高く左右対称に減衰し、
  // リングの輪郭を少しだけ横切る短いリード線を左右に付ける。
  const amps = [0.28, 0.55, 0.82, 1.0, 0.86, 0.66, 0.44, 0.24];
  const wl = ccx - rr, wr = ccx + rr, span = wr - wl;
  const lead = rr * 0.22;
  const wave = [[wl - lead, ccy], [wl, ccy]];
  const N = 96;
  for (let i = 0; i <= N; i++) {
    const t = i / N;
    const x = wl + span * t;
    const edge = Math.pow(Math.sin(t * Math.PI), 0.7);
    const env = amps[Math.floor(t * (amps.length - 1))] * edge;
    const y = ccy - Math.sin(t * Math.PI * 6) * (rr * 0.82) * env;
    wave.push([x, y]);
  }
  wave.push([wr, ccy], [wr + lead, ccy]);

  return { pin, ring, wave };
}

function encodePng(buf) {
  // raw: 各行先頭にフィルタバイト0
  const raw = Buffer.alloc(SIZE * (SIZE * 4 + 1));
  for (let y = 0; y < SIZE; y++) {
    raw[y * (SIZE * 4 + 1)] = 0;
    for (let x = 0; x < SIZE * 4; x++) {
      raw[y * (SIZE * 4 + 1) + 1 + x] = buf[y * SIZE * 4 + x];
    }
  }
  const idat = zlib.deflateSync(raw, { level: 9 });

  const chunk = (type, data) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length, 0);
    const typeBuf = Buffer.from(type, 'ascii');
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])) >>> 0, 0);
    return Buffer.concat([len, typeBuf, data, crc]);
  };

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(SIZE, 0);
  ihdr.writeUInt32BE(SIZE, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;

  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', idat),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

// 角丸長方形の輪郭ポリライン。
function roundedRectPoints(x, y, w, h, r) {
  const pts = [];
  const corner = (cxx, cyy, start) => {
    for (let i = 0; i <= 16; i++) {
      const a = start + (Math.PI / 2) * (i / 16);
      pts.push([cxx + r * Math.cos(a), cyy + r * Math.sin(a)]);
    }
  };
  // 上辺→右上→右辺→右下→下辺→左下→左辺→左上 の順
  pts.push([x + r, y]);
  pts.push([x + w - r, y]);
  corner(x + w - r, y + r, -Math.PI / 2);
  pts.push([x + w, y + h - r]);
  corner(x + w - r, y + h - r, 0);
  pts.push([x + r, y + h]);
  corner(x + r, y + h - r, Math.PI / 2);
  pts.push([x, y + r]);
  corner(x + r, y + r, Math.PI);
  pts.push([x + r, y]);
  return pts;
}

function render({ withBg, scale, frame }) {
  const buf = makeBuffer();
  if (withBg) fillBg(buf, NAVY, 1);
  if (frame) {
    const inset = SIZE * 0.085;
    const fr = roundedRectPoints(
      inset, inset, SIZE - inset * 2, SIZE - inset * 2, SIZE * 0.2);
    stampStroke(buf, fr, 34);
  }
  const motifScale = frame ? scale * 0.78 : scale; // フレーム内に収める
  const { pin, ring, wave } = buildMotif(motifScale, SIZE / 2, SIZE / 2);
  const sw = 46 * motifScale;
  stampStroke(buf, pin, sw);
  stampStroke(buf, ring, sw * 0.92);
  stampStroke(buf, wave, sw);
  return encodePng(buf);
}

const outDir = path.join(__dirname, '..', 'assets', 'icon');
fs.mkdirSync(outDir, { recursive: true });

// 1) 標準（四角内モチーフのみ・フレーム無し）
fs.writeFileSync(path.join(outDir, 'app_icon.png'),
  render({ withBg: true, scale: 1.0 }));
// 2) フルアイコン（外周の角丸グラデフレーム付き＝共有アイコンに忠実）
fs.writeFileSync(path.join(outDir, 'app_icon_framed.png'),
  render({ withBg: true, scale: 1.0, frame: true }));
// 3) Adaptive 前景（透過・セーフゾーン縮小）
fs.writeFileSync(path.join(outDir, 'app_icon_foreground.png'),
  render({ withBg: false, scale: 0.66 }));
console.log('Generated app_icon.png / app_icon_framed.png / app_icon_foreground.png');
