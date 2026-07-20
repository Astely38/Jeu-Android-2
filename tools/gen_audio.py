#!/usr/bin/env python3
"""Génère des bruitages du jeu (WAV PCM 16 bits mono), sans dépendance externe.
Purement procédural : synthèse additive + enveloppes ADSR + filtre passe-bas +
délai, avec bouclage sans couture par recouvrement tête/queue.

La MUSIQUE n'est plus synthétisée ici : le jeu utilise désormais des pistes
réelles au thème japonais (assets/music/*.ogg|mp3, voir CREDITS.md et
scripts/music_manager.gd). Les fonctions make_world2/make_bossfinal ont été
retirées ; seuls les bruitages restent générés.

Sorties :
  assets/sfx/clink.wav        bruitage de coup paré/bloqué (métallique)
"""
import math, struct, wave, os, random

def nfreq(midi):
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))

def adsr(n, sr, a, d, s, r):
    """Enveloppe ADSR échantillonnée sur n échantillons."""
    env = [0.0] * n
    ai = int(a * sr); di = int(d * sr); ri = int(r * sr)
    si = max(0, n - ai - di - ri)
    idx = 0
    for i in range(ai):
        if idx < n: env[idx] = i / max(1, ai); idx += 1
    for i in range(di):
        if idx < n: env[idx] = 1.0 + (s - 1.0) * (i / max(1, di)); idx += 1
    for i in range(si):
        if idx < n: env[idx] = s; idx += 1
    for i in range(ri):
        if idx < n: env[idx] = s * (1.0 - i / max(1, ri)); idx += 1
    return env

def render_note(buf, sr, start, dur, freq, amp, harmonics=(1.0,), detune=0.0,
                a=0.01, d=0.1, s=0.7, r=0.2):
    """Additionne une note (somme d'harmoniques sinus) dans buf."""
    n = int(dur * sr)
    env = adsr(n, sr, a, d, s, r)
    two_pi = 2.0 * math.pi
    for h_i, h_amp in enumerate(harmonics):
        f = freq * (h_i + 1) * (1.0 + detune * (h_i))
        w = two_pi * f / sr
        for i in range(n):
            si = start + i
            if 0 <= si < len(buf):
                buf[si] += math.sin(w * i) * h_amp * amp * env[i]

def render_noise(buf, sr, start, dur, amp, a=0.5, d=0.5, s=0.6, r=1.0, lp=0.15):
    """Nappe de bruit filtré (vent/souffle) additionnée dans buf."""
    n = int(dur * sr)
    env = adsr(n, sr, a, d, s, r)
    prev = 0.0
    for i in range(n):
        si = start + i
        white = random.uniform(-1.0, 1.0)
        prev = prev + lp * (white - prev)  # passe-bas un pôle
        if 0 <= si < len(buf):
            buf[si] += prev * amp * env[i]

def one_pole_lp(buf, coef):
    prev = 0.0
    for i in range(len(buf)):
        prev = prev + coef * (buf[i] - prev)
        buf[i] = prev

def delay(buf, sr, time, feedback, mix):
    d = int(time * sr)
    if d <= 0: return
    for i in range(d, len(buf)):
        buf[i] += buf[i - d] * feedback * mix

def seamless(buf, sr, overlap):
    """Boucle sans couture : recouvre la queue sur la tête en fondu croisé.
    Renvoie buf tronqué à (len - overlap) échantillons, bouclable proprement."""
    ov = int(overlap * sr)
    n = len(buf)
    if ov <= 0 or ov * 2 >= n: return buf
    head = buf[:ov]
    tail = buf[n - ov:]
    out = buf[:n - ov]
    for i in range(ov):
        f = i / ov
        out[i] = head[i] * f + tail[i] * (1.0 - f)
    return out

def normalize(buf, peak=0.86):
    m = max(1e-9, max(abs(x) for x in buf))
    g = peak / m
    for i in range(len(buf)):
        x = buf[i] * g
        buf[i] = math.tanh(x * 1.1)  # limiteur doux

def write_wav(path, buf, sr):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    w = wave.open(path, 'wb')
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
    frames = bytearray()
    for x in buf:
        v = int(max(-1.0, min(1.0, x)) * 32767)
        frames += struct.pack('<h', v)
    w.writeframes(bytes(frames)); w.close()
    print("écrit", path, "%.1fs" % (len(buf) / sr))

# ----------------------------------------------------------------------------
SR = 22050
random.seed(7)

def make_clink():
    """Coup paré/bloqué : transitoire métallique inharmonique bref."""
    sr = 44100
    dur = 0.16
    n = int(dur * sr)
    buf = [0.0] * n
    partials = [(2150, 1.0), (3370, 0.7), (5210, 0.5), (7100, 0.35), (9300, 0.2)]
    for f, a in partials:
        for i in range(n):
            buf[i] += math.sin(2 * math.pi * f * i / sr) * a * math.exp(-34.0 * i / sr)
    # Transitoire de bruit très court au départ.
    for i in range(int(0.006 * sr)):
        buf[i] += random.uniform(-1, 1) * 0.8 * math.exp(-400.0 * i / sr)
    normalize(buf, 0.8)
    write_wav("assets/sfx/clink.wav", buf, sr)

if __name__ == "__main__":
    make_clink()
