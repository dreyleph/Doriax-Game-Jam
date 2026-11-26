# montar_sprites_itens.py
# Gera as imagens dos itens no tamanho em que aparecem no jogo (assets/Itens/)
# a partir das artes originais do Edu (128x128 / 100x100, em assets/). Os
# originais nao sao alterados.
#
# Por que reduzir antes: a arte original e grande (128 px) e o item no chao
# tem ~48 px. Reduzir aqui com um filtro de qualidade fica melhor do que deixar
# a engine encolher na hora (o filtro "nearest" pula pixels e a arte fica
# picotada).
#
# Para trocar uma arte ou o tamanho: edite ITENS e rode
#   python tools/montar_sprites_itens.py
# Os tamanhos finais aparecem no console; copie-os para Itens.TYPES (campo sprite).
# Requer Pillow (pip install pillow).
import os
from PIL import Image

ASSETS = os.path.join(os.path.dirname(__file__), "..", "assets")
SAIDA = os.path.join(ASSETS, "Itens")

# arquivo original -> (arquivo gerado, largura maxima, altura maxima)
ITENS = {
    "Kraby1.png":    ("caranguejo.png", 52, 48),
    "Musket.png":    ("escopeta.png",   72, 40),
    "PisaMacio.png": ("pisa_macio.png", 48, 48),
}

os.makedirs(SAIDA, exist_ok=True)
for origem, (destino, maxW, maxH) in ITENS.items():
    img = Image.open(os.path.join(ASSETS, origem)).convert("RGBA")
    img = img.crop(img.getbbox())   # tira a borda transparente
    escala = min(maxW / img.width, maxH / img.height)
    w, h = max(1, round(img.width * escala)), max(1, round(img.height * escala))
    img = img.resize((w, h), Image.LANCZOS)
    img.save(os.path.join(SAIDA, destino))
    print("%-14s -> Itens/%-15s %dx%d" % (origem, destino, w, h))
