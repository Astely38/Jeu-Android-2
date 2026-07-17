#!/usr/bin/env python3
"""Génère les nouvelles pistes musicales et bruitages du jeu (WAV PCM 16 bits
mono), sans dépendance externe. Purement procédural : synthèse additive +
enveloppes ADSR + filtre passe-bas + délai, avec bouclage sans couture par
recouvrement tête/queue.

Sorties :
  assets/music/world2.wav    thème d'exploration du Chapitre II (sombre)
  assets/music/bossfinal.wav thème du boss final (le Cœur de l'Ombre)
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

def make_world2():
    """Chapitre II : ré mineur lent et sombre, pad + basse + cloches + vent."""
    bars = 8
    bar = 4.0
    overlap = 0.6
    total = bars * bar + overlap
    buf = [0.0] * int(total * SR)
    PAD = (1.0, 0.5, 0.28, 0.14)  # harmoniques (timbre chaud)
    # Triades (pad, octave medium) par mesure.
    prog = [
        (62, 65, 69),  # Dm
        (62, 65, 69),  # Dm
        (58, 62, 65),  # Bb
        (55, 58, 62),  # Gm
        (62, 65, 69),  # Dm
        (58, 62, 65),  # Bb
        (57, 61, 64),  # A (dominante)
        (57, 61, 64),  # A
    ]
    bass = [38, 38, 46, 43, 38, 46, 45, 45]  # racines une octave plus bas
    for b in range(bars):
        st = int(b * bar * SR)
        for m in prog[b]:
            render_note(buf, SR, st, bar + 0.4, nfreq(m), 0.16, PAD,
                        a=0.6, d=0.8, s=0.75, r=1.2)
        # Basse sur temps 1 et 3.
        for beat in (0, 2):
            bs = int((b * bar + beat) * SR)
            render_note(buf, SR, bs, 1.6, nfreq(bass[b]), 0.34, (1.0, 0.4),
                        a=0.01, d=0.3, s=0.5, r=0.6)
    # Cloches éparses (mélodie), une note toutes les deux mesures.
    bells = [74, 81, 77, 84]  # D5 A5 F5 C6
    for i, mel in enumerate(bells):
        st = int((i * 2 * bar + 1.0) * SR)
        render_note(buf, SR, st, 3.2, nfreq(mel), 0.14, (1.0, 0.6, 0.3),
                    a=0.02, d=0.6, s=0.3, r=2.2)
    # Souffle de vent en fond.
    render_noise(buf, SR, 0, total, 0.05, a=2.0, d=2.0, s=0.7, r=2.0, lp=0.08)
    one_pole_lp(buf, 0.5)
    delay(buf, SR, 0.5, 0.35, 0.5)
    buf = seamless(buf, SR, overlap)
    normalize(buf, 0.82)
    write_wav("assets/music/world2.wav", buf, SR)

def make_bossfinal():
    """Boss final : ré mineur rapide, ostinato de basse pilonnant + tension."""
    bars = 16
    bpm = 138.0
    beat = 60.0 / bpm
    bar = beat * 4
    overlap = beat
    total = bars * bar + overlap
    buf = [0.0] * int(total * SR)
    PAD = (1.0, 0.6, 0.4, 0.25, 0.16)
    # Pad de tension : change tous les 4 mesures (Dm, Bb, Ab, A).
    chords = [(50, 53, 57), (46, 50, 53), (56, 60, 63), (57, 61, 64)]
    for seg in range(4):
        st = int(seg * 4 * bar * SR)
        for m in chords[seg]:
            render_note(buf, SR, st, 4 * bar + 0.2, nfreq(m + 12), 0.10, PAD,
                        a=0.3, d=1.0, s=0.6, r=0.8)
    # Ostinato de basse : croches sur ré, accent sur le temps.
    for b in range(bars):
        for e in range(8):  # 8 croches par mesure
            t = (b * bar) + e * (beat / 2.0)
            st = int(t * SR)
            note = 38  # D2
            if e in (6, 7) and b % 4 == 3:
                note = 44  # Ab2 : triton de tension en fin de phrase
            accent = 0.42 if e % 2 == 0 else 0.28
            render_note(buf, SR, st, beat * 0.5, nfreq(note), accent,
                        (1.0, 0.5, 0.25), a=0.005, d=0.08, s=0.35, r=0.12)
        # Kick sourd sur chaque temps.
        for k in range(4):
            st = int((b * bar + k * beat) * SR)
            n = int(0.12 * SR)
            for i in range(n):
                si = st + i
                if 0 <= si < len(buf):
                    f = 90.0 * math.exp(-14.0 * i / SR) + 40.0
                    buf[si] += math.sin(2 * math.pi * f * i / SR) * 0.5 * math.exp(-16.0 * i / SR)
    # Motif de tête aigu toutes les 4 mesures (dread).
    lead = [74, 75, 81, 80]  # D5 Eb5 A5 Ab5
    for i, mel in enumerate(lead):
        st = int((i * 4 * bar + bar * 2) * SR)
        render_note(buf, SR, st, bar * 1.5, nfreq(mel), 0.12, (1.0, 0.7, 0.4),
                    a=0.02, d=0.4, s=0.4, r=1.0)
    one_pole_lp(buf, 0.62)
    delay(buf, SR, beat / 2.0, 0.28, 0.4)
    buf = seamless(buf, SR, overlap)
    normalize(buf, 0.9)
    write_wav("assets/music/bossfinal.wav", buf, SR)

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
    make_world2()
    make_bossfinal()
    make_clink()
