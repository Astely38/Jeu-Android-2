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

def make_footstep():
    """Pas d'Eneko : bruit de sol court et mat (terre/herbe). Discret, il est
    joué en boucle à la cadence de la course avec une variation de hauteur."""
    sr = 44100
    dur = 0.13
    n = int(dur * sr)
    buf = [0.0] * n
    # Corps mat : sinus basse fréquence qui glisse vers le grave, decay rapide.
    for i in range(n):
        t = i / sr
        f = 150.0 * math.exp(-38.0 * t) + 58.0
        buf[i] += math.sin(2.0 * math.pi * f * t) * 0.55 * math.exp(-46.0 * t)
    # Grattement de surface : courte bouffée de bruit passe-bas.
    prev = 0.0
    for i in range(n):
        t = i / sr
        white = random.uniform(-1.0, 1.0)
        prev = prev + 0.22 * (white - prev)  # passe-bas un pôle
        buf[i] += prev * 0.4 * math.exp(-58.0 * t)
    # Micro-transitoire d'attaque (le contact du pied).
    for i in range(int(0.004 * sr)):
        buf[i] += random.uniform(-1, 1) * 0.5 * math.exp(-500.0 * i / sr)
    normalize(buf, 0.55)  # volume discret : un pas ne doit pas couvrir le jeu
    write_wav("assets/sfx/footstep.wav", buf, sr)

def make_land():
    """Réception de saut : impact FRANC dont toute l'énergie est dès le premier
    échantillon (pas de montée d'attaque, sinon le son semble arriver en
    retard). Smack sec + corps sourd qui descend + traîne de gravier."""
    sr = 44100
    dur = 0.22
    n = int(dur * sr)
    buf = [0.0] * n
    # Smack d'attaque : bouffée de bruit forte et très courte, dès i = 0.
    for i in range(int(0.007 * sr)):
        buf[i] += random.uniform(-1, 1) * 0.95 * math.exp(-320.0 * i / sr)
    # Corps sourd : sinus grave qui glisse vers le bas, decay rapide.
    for i in range(n):
        t = i / sr
        f = 98.0 * math.exp(-22.0 * t) + 46.0
        buf[i] += math.sin(2.0 * math.pi * f * t) * 0.7 * math.exp(-23.0 * t)
    # Gravier soulevé : bruit passe-bas qui retombe.
    prev = 0.0
    for i in range(n):
        t = i / sr
        white = random.uniform(-1.0, 1.0)
        prev = prev + 0.18 * (white - prev)
        buf[i] += prev * 0.28 * math.exp(-28.0 * t)
    normalize(buf, 0.85)  # réception franche et bien présente
    write_wav("assets/sfx/land.wav", buf, sr)

def make_karasu_die():
    """Mort du Karasu-tengu : cri de corbeau rauque et descendant, teinté
    spectral (souffle aigu qui s'éteint). Court et perçant."""
    sr = 44100
    dur = 0.34
    n = int(dur * sr)
    buf = [0.0] * n
    for i in range(n):
        t = i / sr
        # Hauteur qui plonge : le cri qui « casse » vers le grave.
        f = 760.0 * math.exp(-3.4 * t) + 300.0
        s = 0.0
        for h, amp in [(1, 1.0), (2, 0.5), (3, 0.62), (4, 0.28), (5, 0.36)]:
            s += math.sin(2.0 * math.pi * f * h * t) * amp
        s /= 2.8
        # Rasp du corbeau : trémolo rapide de l'amplitude.
        rasp = 0.58 + 0.42 * math.sin(2.0 * math.pi * 74.0 * t)
        env = math.exp(-6.8 * t) * (1.0 - math.exp(-140.0 * t))
        buf[i] += s * rasp * env * 0.9
    # Souffle spectral : bruit passe-haut qui s'efface.
    prev = 0.0
    for i in range(n):
        t = i / sr
        white = random.uniform(-1.0, 1.0)
        prev = prev + 0.5 * (white - prev)
        buf[i] += (white - prev) * 0.32 * math.exp(-7.5 * t)
    normalize(buf, 0.8)
    write_wav("assets/sfx/karasu_die.wav", buf, sr)

def make_oni_die():
    """Chute de l'Oni au pavois : fracas métallique de l'armure + choc sourd
    au sol, puis les plaques qui retombent. Lourd et grave."""
    sr = 44100
    dur = 0.5
    n = int(dur * sr)
    buf = [0.0] * n
    # Fracas métallique inharmonique (armure/pavois), decay moyen.
    for f, a in [(430, 1.0), (645, 0.7), (1015, 0.55), (1560, 0.4), (2280, 0.22)]:
        for i in range(n):
            t = i / sr
            buf[i] += math.sin(2.0 * math.pi * f * t) * a * math.exp(-9.0 * t) * 0.5
    # Choc sourd : corps grave qui glisse vers le bas.
    for i in range(n):
        t = i / sr
        f = 112.0 * math.exp(-16.0 * t) + 42.0
        buf[i] += math.sin(2.0 * math.pi * f * t) * 0.8 * math.exp(-13.0 * t)
    # Transitoire métallique d'attaque.
    for i in range(int(0.006 * sr)):
        buf[i] += random.uniform(-1, 1) * 0.7 * math.exp(-360.0 * i / sr)
    # Plaques qui retombent : bruit grave différé.
    prev = 0.0
    for i in range(n):
        t = i / sr
        white = random.uniform(-1.0, 1.0)
        prev = prev + 0.15 * (white - prev)
        gate = 1.0 if t > 0.06 else 0.3
        buf[i] += prev * 0.22 * math.exp(-6.0 * t) * gate
    normalize(buf, 0.85)
    write_wav("assets/sfx/oni_die.wav", buf, sr)

if __name__ == "__main__":
    make_clink()
    make_footstep()
    make_land()
    make_karasu_die()
    make_oni_die()
