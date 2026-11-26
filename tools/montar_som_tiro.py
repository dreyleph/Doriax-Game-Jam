# montar_som_tiro.py
# Gera o som de tiro usado no jogo (assets/Sons/tiro.wav) a partir do original
# (assets/Sons/tiro_original.mp3, que nao e alterado).
#
# Por que cortar: o original tem ~0,1 s de silencio antes do estampido (o tiro
# soaria atrasado) e 3 s no total, quase tudo uma cauda baixa; com o tiro
# rapido do Charuto essas caudas se acumulariam. Aqui ele comeca logo antes do
# estampido e termina com um fade-out curto.
#
# Para trocar o som ou o corte: edite as constantes e rode
#   python tools/montar_som_tiro.py
# Requer miniaudio (pip install miniaudio).
import array
import os
import wave

import miniaudio

SONS = os.path.join(os.path.dirname(__file__), "..", "assets", "Sons")
ORIGEM = "tiro_original.mp3"
SAIDA = "tiro.wav"
INICIO = 0.085   # s: corta o silencio do comeco (o estampido esta em ~0.097 s)
DURACAO = 0.9    # s: tamanho final
FADE = 0.3       # s: fade-out no fim

# le os bytes aqui: o miniaudio nao abre caminhos com acento (ex.: "Programação")
with open(os.path.join(SONS, ORIGEM), "rb") as f:
    d = miniaudio.decode(f.read(), output_format=miniaudio.SampleFormat.SIGNED16)
sr, ch = d.sample_rate, d.nchannels
ini = int(INICIO * sr)
n = min(int(DURACAO * sr), len(d.samples) // ch - ini)
amostras = array.array("h", d.samples[ini * ch:(ini + n) * ch])
fade = int(FADE * sr)
for i in range(max(n - fade, 0), n):
    g = (n - i) / fade
    for c in range(ch):
        k = i * ch + c
        amostras[k] = int(amostras[k] * g)

with wave.open(os.path.join(SONS, SAIDA), "wb") as w:
    w.setnchannels(ch)
    w.setsampwidth(2)
    w.setframerate(sr)
    w.writeframes(amostras.tobytes())
print("Gerado Sons/%s (%.2f s, %d Hz, %d canais)" % (SAIDA, n / sr, sr, ch))
