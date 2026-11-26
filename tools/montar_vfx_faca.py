# montar_vfx_faca.py
# Gera as sprite sheets do efeito da faca (assets/VFX/) a partir do pacote
# "SLASH VFX" (assets/SLASH VFX/, 6 quadros de 550x400 por golpe). Os
# originais nao sao alterados.
#
#   faca_frente.png : "White Slash Wide" (arco largo), para o golpe para a frente
#   faca_cima.png   : "White Slash Thin" (arco fino e comprido), para cima/baixo
#
# Cada quadro e recortado na area que o golpe ocupa (a mesma para os 6, para o
# arco nao "pular") e reduzido para 4x o tamanho em que aparece no jogo
# (Player.lua desenha no tamanho da area de acerto da faca).
# Rode na pasta do projeto: python tools/montar_vfx_faca.py  (requer Pillow)
import glob, os
from PIL import Image

ASSETS = os.path.join(os.path.dirname(__file__), "..", "assets")
ORIGEM = os.path.join(ASSETS, "SLASH VFX")
SAIDA = os.path.join(ASSETS, "VFX")
# pasta -> (arquivo gerado, largura e altura de cada quadro)
EFEITOS = {
    "White Slash Wide": ("faca_frente.png", 120, 88),
    "White Slash Thin": ("faca_cima.png", 256, 88),
}

def numero(caminho):
    return int("".join(c for c in os.path.basename(caminho) if c.isdigit()))

os.makedirs(SAIDA, exist_ok=True)
for pasta, (destino, fw, fh) in EFEITOS.items():
    quadros = [Image.open(f).convert("RGBA") for f in sorted(glob.glob(os.path.join(ORIGEM, pasta, "*.png")), key=numero)]
    caixas = [q.getbbox() for q in quadros if q.getbbox()]
    area = (min(c[0] for c in caixas), min(c[1] for c in caixas), max(c[2] for c in caixas), max(c[3] for c in caixas))
    folha = Image.new("RGBA", (fw * len(quadros), fh), (0, 0, 0, 0))
    for i, q in enumerate(quadros):
        folha.paste(q.crop(area).resize((fw, fh), Image.LANCZOS), (i * fw, 0))
    folha.save(os.path.join(SAIDA, destino))
    print("%-18s -> VFX/%s  %d quadros de %dx%d (area original %s)" % (pasta, destino, len(quadros), fw, fh, area))
