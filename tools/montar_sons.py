# montar_sons.py
# Gera os sons usados no jogo (assets/Sons/*.wav) a partir dos originais
# (assets/Sons/*_original.mp3, que nao sao alterados).
#
# Por que cortar: os originais tem silencio no comeco (o som sairia atrasado)
# e varios segundos de cauda baixa. Aqui cada som comeca logo antes do que
# importa, termina com um fade-out curto e, se pedido, tem o volume ajustado
# (os originais dos itens sao bem mais baixos que o tiro).
#
# Para trocar um som ou o corte: edite SONS e rode
#   python tools/montar_sons.py
# Requer miniaudio (pip install miniaudio).
import array
import os
import wave

import miniaudio

PASTA = os.path.join(os.path.dirname(__file__), "..", "assets", "Sons")

# original -> (gerado, inicio (s), duracao (s), fade-out (s), pico alvo em dBFS ou None = sem ajuste)
SONS = {
    "tiro_original.mp3":       ("tiro.wav",       0.085, 0.9, 0.3, None),  # tiro do jogador (J / K)
    "charuto_original.mp3":    ("charuto.wav",    0.0,   3.0, 1.0, -12.0), # pegou o Charuto
    "beber_original.mp3":      ("beber.wav",      0.42,  2.8, 0.4, -6.0),  # pegou o Pisa Macio
    "caranguejo_original.mp3": ("caranguejo.wav", 0.72,  1.4, 0.4, -6.0),  # pegou o Caranguejo
}

for origem, (saida, inicio, duracao, fade_s, pico) in SONS.items():
    # le os bytes aqui: o miniaudio nao abre caminhos com acento (ex.: "Programação")
    with open(os.path.join(PASTA, origem), "rb") as f:
        d = miniaudio.decode(f.read(), output_format=miniaudio.SampleFormat.SIGNED16)
    sr, ch = d.sample_rate, d.nchannels
    ini = int(inicio * sr)
    n = min(int(duracao * sr), len(d.samples) // ch - ini)
    amostras = array.array("h", d.samples[ini * ch:(ini + n) * ch])

    ganho = 1.0
    if pico is not None:
        maior = max(1, max(abs(x) for x in amostras))
        ganho = (32767 * 10 ** (pico / 20)) / maior

    fade = max(1, int(fade_s * sr))
    for i in range(n):
        g = ganho * (min(1.0, (n - i) / fade) if i >= n - fade else 1.0)
        if g == 1.0:
            continue
        for c in range(ch):
            k = i * ch + c
            amostras[k] = max(-32768, min(32767, int(amostras[k] * g)))

    with wave.open(os.path.join(PASTA, saida), "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(amostras.tobytes())
    print("Gerado Sons/%-15s %.2f s, %d Hz, %d canais, ganho %.1fx" % (saida, n / sr, sr, ch, ganho))
