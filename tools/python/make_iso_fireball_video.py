"""Combine the isometric fireball animation with the synthesized sound effects into an MP4.

Needs: make_sfx.py run first (./sfx/*.wav). Renders frames via make_iso_fireball.py.
Output: iso/iso_fireball.mp4, sfx/fireball_scene_mix.wav
"""
import numpy as np, os, wave, subprocess, tempfile
import make_iso_fireball as A
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SFX = os.path.join(HERE, "sfx")
SR = 44100


def load(name):
    with wave.open(os.path.join(SFX, name + ".wav")) as w:
        return np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32767


# frame start times (seconds) from the animation's own durations
starts = np.concatenate([[0], np.cumsum(A.durs)]) / 1000
total = starts[-1] + 0.3
# section boundaries in make_iso_fireball: 6 targeting, 5 casting, NF flight, 10 explosion, 6 aftermath
i_cast, i_flight = 6, 11
i_boom = i_flight + A.NF
i_after = i_boom + 10
events = [  # (time, sound, volume)
    (starts[1], "ui_select", 0.8),
    (starts[i_cast], "charge", 0.9),
    (starts[i_flight] - 0.03, "cast_whoosh", 0.9),
    (starts[i_flight], "fireball_flight", 0.8),
    (starts[i_boom], "explosion", 1.0),
    (starts[i_boom] + 0.02, "monster_hurt", 0.7),
    (starts[i_boom + 2], "monster_death", 0.8),
    (starts[i_after] + 0.35, "turn_chime", 0.8),
]

mix = np.zeros(int(SR * total) + SR)
amb = load("torch_ambience")
reps = int(np.ceil(len(mix) / len(amb)))
mix += np.tile(amb, reps)[:len(mix)] * 0.6
for t, name, vol in events:
    s = load(name)
    i = int(t * SR)
    mix[i:i + len(s)] += s[:len(mix) - i] * vol
mix = mix[:int(SR * total)]
mix = np.tanh(mix * 1.1) * 0.95  # soft limiter
with wave.open(os.path.join(SFX, "fireball_scene_mix.wav"), "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((mix * 32767).astype(np.int16).tobytes())

with tempfile.TemporaryDirectory() as tmp:
    lines = []
    for k, (fr, d) in enumerate(zip(A.frames, A.durs)):
        p = os.path.join(tmp, f"f{k:03d}.png")
        fr.resize((A.S.W * 3, A.S.H * 3), Image.NEAREST).save(p)
        lines += [f"file '{p}'", f"duration {d / 1000:.3f}"]
    lines += [f"file '{p}'", "duration 0.300", f"file '{p}'"]
    lst = os.path.join(tmp, "list.txt")
    open(lst, "w").write("\n".join(lines) + "\n")
    out = os.path.join(A.OUT, "iso_fireball.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst,
                    "-i", os.path.join(SFX, "fireball_scene_mix.wav"),
                    "-vf", "fps=30,format=yuv420p", "-c:v", "libx264", "-crf", "16", "-tune", "animation",
                    "-c:a", "aac", "-b:a", "160k", "-shortest", "-movflags", "+faststart", out], check=True)
print("events:", [(round(t, 2), n) for t, n, _ in events])
print("wrote", out)
