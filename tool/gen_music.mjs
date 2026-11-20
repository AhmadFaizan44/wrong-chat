// Renders Wrong Chat's background music: a bright, bouncy "phone-pop" loop (16 bars, 118 BPM, seamless).
// Original composition, synthesised from scratch (no samples).
// Run from wrong-chat/:  node tool/gen_music.mjs
//   then:  ffmpeg -y -i build/music/music.wav -c:a libvorbis -q:a 3 assets/audio/music.ogg
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const out = join(dirname(fileURLToPath(import.meta.url)), '..', 'build', 'music');
mkdirSync(out, { recursive: true });

const RATE = 44100;
const BPM = 118;
const BEAT = 60 / BPM;
const BARS = 16;
const LEN = Math.round(BARS * 4 * BEAT * RATE);
const L = new Float32Array(LEN);
const R = new Float32Array(LEN);
const TAU = Math.PI * 2;

let seed = 424242;
const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296) * 2 - 1;
const hz = (midi) => 440 * Math.pow(2, (midi - 69) / 12);

/** Adds a voice; samples wrap so the loop is seamless. pan: -1..1 */
function add(startSec, durSec, fn, pan = 0) {
  const s0 = Math.round(startSec * RATE);
  const n = Math.round(durSec * RATE);
  const gl = Math.cos(((pan + 1) * Math.PI) / 4);
  const gr = Math.sin(((pan + 1) * Math.PI) / 4);
  for (let i = 0; i < n; i++) {
    const v = fn(i / RATE);
    const k = (s0 + i) % LEN;
    L[k] += v * gl;
    R[k] += v * gr;
  }
}

// ---------------------------------------------------------------- instruments

/** Electric piano: 2-operator FM with a bell-ish attack. */
function epiano(t0, midi, dur, vel, pan) {
  const f = hz(midi);
  add(t0, dur + 0.5, (t) => {
    const env = Math.min(1, t / 0.005) * (t < dur ? Math.exp(-t * 1.6) : Math.exp(-dur * 1.6) * Math.exp(-(t - dur) * 9));
    const idx = 1.6 * Math.exp(-t * 6) + 0.25;
    return vel * env * Math.sin(TAU * f * t + idx * Math.sin(TAU * f * t));
  }, pan);
}

/** Notification "ping": glassy sine with a fast upward blip. The game's signature ear candy. */
function ping(t0, midi, vel, pan) {
  const f = hz(midi);
  add(t0, 0.6, (t) => {
    const ff = f * (1 + 0.03 * Math.exp(-t * 60));
    const env = Math.min(1, t / 0.002) * Math.exp(-t * 7);
    return vel * env * (Math.sin(TAU * ff * t) + 0.3 * Math.sin(TAU * ff * 3 * t) * Math.exp(-t * 20));
  }, pan);
}

/** Pluck lead (saw-ish, softened). */
function lead(t0, midi, dur, vel, pan) {
  const f = hz(midi);
  add(t0, dur + 0.2, (t) => {
    const env = Math.min(1, t / 0.006) * (t < dur ? Math.exp(-t * 3.2) : Math.exp(-dur * 3.2) * Math.exp(-(t - dur) * 25));
    const vib = 1 + 0.004 * Math.sin(TAU * 5.5 * t) * Math.min(1, t * 4);
    let v = 0;
    for (let h = 1; h <= 5; h++) v += Math.sin(TAU * f * vib * h * t) / (h * h * 0.8);
    return vel * env * v * 0.6;
  }, pan);
}

/** Round sub bass with a little growl. */
function bass(t0, midi, dur, vel) {
  const f = hz(midi);
  add(t0, dur + 0.1, (t) => {
    const env = Math.min(1, t / 0.006) * (t < dur ? 1 - 0.35 * (t / dur) : 0.65 * Math.exp(-(t - dur) * 40));
    return vel * env * (Math.sin(TAU * f * t) + 0.18 * Math.sin(TAU * f * 2 * t) + 0.06 * Math.sin(TAU * f * 3 * t));
  });
}

function kick(t0, vel) {
  add(t0, 0.3, (t) => {
    const f = 50 + 95 * Math.exp(-t * 35);
    return vel * Math.exp(-t * 13) * Math.sin(TAU * f * t);
  });
}

/** Hand clap: three quick noise bursts then a short tail. */
function clap(t0, vel) {
  let lp = 0;
  add(t0, 0.22, (t) => {
    const burst = (t < 0.01 ? 1 : t < 0.02 ? 0.6 : 0.85) * Math.exp(-Math.max(0, t - 0.022) * 28);
    const x = rnd();
    lp += (x - lp) * 0.35;
    return vel * burst * (x - lp);
  }, 0.1);
}

function hat(t0, vel, pan, open = false) {
  let prev = 0;
  add(t0, open ? 0.2 : 0.05, (t) => {
    const x = rnd();
    const hp = x - prev;
    prev = x;
    return vel * Math.exp(-t * (open ? 18 : 80)) * hp;
  }, pan);
}

/** Warm pad under everything. */
function pad(t0, notes, dur, vel) {
  notes.forEach((m, k) => {
    const f = hz(m);
    const pan = (k - (notes.length - 1) / 2) * 0.4;
    add(t0, dur + 0.5, (t) => {
      const a = Math.min(1, t / 0.6);
      const r = t > dur ? Math.exp(-(t - dur) * 6) : 1;
      return (vel * a * r * (Math.sin(TAU * f * t) + Math.sin(TAU * f * 1.006 * t + 2))) / 2;
    }, pan);
  });
}

// ---------------------------------------------------------------- arrangement
// One chord per bar: Fmaj7 G6 Em7 Am7 | Dm9 G Cmaj7 E7(b9-ish) ... repeated with a lift in the second half.
const CH = [
  { root: 41, keys: [57, 60, 64, 65] }, // Fmaj7
  { root: 43, keys: [55, 59, 62, 64] }, // G6
  { root: 40, keys: [55, 59, 62, 64] }, // Em7
  { root: 45, keys: [55, 57, 60, 64] }, // Am7
  { root: 38, keys: [57, 60, 64, 65] }, // Dm9
  { root: 43, keys: [55, 59, 62, 67] }, // G
  { root: 48, keys: [55, 59, 64, 67] }, // Cmaj7
  { root: 40, keys: [56, 59, 62, 64] }, // E7
];

// Lead motif per bar, [beat, midi, len] in A minor / C major.
const MOTIF = [
  [[0.5, 72, 0.4], [1, 76, 0.4], [1.5, 77, 0.9], [3, 76, 0.4], [3.5, 72, 0.4]],
  [[0, 74, 0.9], [1.5, 71, 0.4], [2, 74, 0.4], [2.5, 79, 1.2]],
  [[0.5, 76, 0.4], [1, 79, 0.4], [1.5, 83, 0.9], [3, 81, 0.4], [3.5, 79, 0.4]],
  [[0, 76, 1.4], [2, 72, 0.4], [2.5, 74, 0.4], [3, 76, 0.9]],
  [[0.5, 77, 0.4], [1, 81, 0.4], [1.5, 84, 0.9], [3, 81, 0.4], [3.5, 77, 0.4]],
  [[0, 79, 0.9], [1.5, 74, 0.4], [2, 79, 0.4], [2.5, 83, 1.2]],
  [[0.5, 84, 0.4], [1, 83, 0.4], [1.5, 79, 0.9], [3, 76, 0.4], [3.5, 79, 0.4]],
  [[0, 80, 0.9], [1, 83, 0.4], [1.5, 80, 0.4], [2, 76, 1.6]],
];

for (let bar = 0; bar < BARS; bar++) {
  const t0 = bar * 4 * BEAT;
  const ch = CH[bar % 8];
  const lift = bar >= 8;

  pad(t0, ch.keys.map((m) => m + 12), 4 * BEAT - 0.05, 0.028);

  // bouncy e-piano stabs on the off-beats (the "texting" rhythm)
  for (const b of [0.5, 1.5, 2.5, 3.25, 3.5]) {
    ch.keys.forEach((m, k) => epiano(t0 + b * BEAT, m, 0.22 * BEAT, 0.045, (k - 1.5) * 0.3));
  }

  // bass: root, octave hop, fifth, approach note
  bass(t0, ch.root, 0.9 * BEAT, 0.3);
  bass(t0 + 1.5 * BEAT, ch.root + 12, 0.35 * BEAT, 0.18);
  bass(t0 + 2 * BEAT, ch.root, 0.6 * BEAT, 0.26);
  bass(t0 + 2.75 * BEAT, ch.root + 7, 0.5 * BEAT, 0.22);
  bass(t0 + 3.5 * BEAT, ch.root + (bar % 2 ? 10 : 12), 0.4 * BEAT, 0.18);

  // drums
  for (let b = 0; b < 4; b++) kick(t0 + b * BEAT, b % 2 ? 0.26 : 0.34);
  clap(t0 + 1 * BEAT, 0.16);
  clap(t0 + 3 * BEAT, 0.16);
  for (let e = 0; e < 8; e++) {
    const open = e === 7 && bar % 2 === 1;
    hat(t0 + e * 0.5 * BEAT, e % 2 ? 0.07 : 0.035, e % 2 ? 0.35 : -0.35, open);
  }
  if (lift) for (let s = 0; s < 16; s += 2) hat(t0 + (s + 1) * 0.25 * BEAT, 0.022, 0.6);

  // lead: only in the second half, so the loop builds and then breathes
  if (lift) for (const [b, m, len] of MOTIF[bar % 8]) lead(t0 + b * BEAT, m, len * BEAT, 0.07, 0.12);

  // notification pings: a rising "ding-ding" every 2 bars, answered in the other ear
  if (bar % 2 === 1) {
    ping(t0 + 3 * BEAT, 88, 0.06, -0.55);
    ping(t0 + 3.25 * BEAT, 95, 0.05, -0.55);
  }
  if (bar % 4 === 2) ping(t0 + 3.5 * BEAT, 91, 0.035, 0.6);
}

// ---------------------------------------------------------------- master
function lowpass(buf, a) {
  let y = 0;
  for (let pass = 0; pass < 2; pass++) {
    for (let i = 0; i < buf.length; i++) {
      y += (buf[i] - y) * a;
      if (pass === 1) buf[i] = y;
    }
  }
}
lowpass(L, 0.62);
lowpass(R, 0.62);
// gentle soft-clip glue
for (let i = 0; i < LEN; i++) {
  L[i] = Math.tanh(L[i] * 1.4);
  R[i] = Math.tanh(R[i] * 1.4);
}
let peak = 0;
for (let i = 0; i < LEN; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
const gain = 0.6 / peak;

const data = Buffer.alloc(LEN * 4);
for (let i = 0; i < LEN; i++) {
  data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, L[i] * gain)) * 32767), i * 4);
  data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, R[i] * gain)) * 32767), i * 4 + 2);
}
const h = Buffer.alloc(44);
h.write('RIFF', 0);
h.writeUInt32LE(36 + data.length, 4);
h.write('WAVE', 8);
h.write('fmt ', 12);
h.writeUInt32LE(16, 16);
h.writeUInt16LE(1, 20);
h.writeUInt16LE(2, 22);
h.writeUInt32LE(RATE, 24);
h.writeUInt32LE(RATE * 4, 28);
h.writeUInt16LE(4, 32);
h.writeUInt16LE(16, 34);
h.write('data', 36);
h.writeUInt32LE(data.length, 40);
const file = join(out, 'music.wav');
writeFileSync(file, Buffer.concat([h, data]));
console.log(`wrote ${file} (${(LEN / RATE).toFixed(1)} s)`);
