# montar_atlas_inimigo.py
# Junta as sprite sheets do inimigo comum (assets/Enemy1/) numa unica imagem
# (atlas), uma animacao por linha, como o atlas do jogador
# (ver montar_atlas_jogador.py: trocar de textura em jogo faz o sprite "bugar").
#
# Quando a arte mudar ou chegar sheet nova: edite LINHAS, rode
#   python tools/montar_atlas_inimigo.py
# e ajuste "first" (linha * COLUNAS) em scripts/enemy/EnemyAnimations.lua.
# Requer Pillow (pip install pillow).
import os
from PIL import Image

PASTA = os.path.join(os.path.dirname(__file__), "..", "assets", "Enemy1")
QUADRO = 128
COLUNAS = 8
LINHAS = [
    ("Runing-Sheet.png", 8),   # linha 0 -> first = 0  andando / correndo
    ("Idle-Sheet.png", 1),     # linha 1 -> first = 8  parado
]
SAIDA = "Inimigo-Atlas.png"

atlas = Image.new("RGBA", (COLUNAS * QUADRO, len(LINHAS) * QUADRO), (0, 0, 0, 0))
for linha, (arquivo, quadros) in enumerate(LINHAS):
    img = Image.open(os.path.join(PASTA, arquivo)).convert("RGBA")
    if quadros > COLUNAS or img.width < quadros * QUADRO or img.height < QUADRO:
        raise SystemExit("%s: tamanho inesperado %dx%d" % (arquivo, img.width, img.height))
    atlas.paste(img.crop((0, 0, quadros * QUADRO, QUADRO)), (0, linha * QUADRO))
atlas.save(os.path.join(PASTA, SAIDA))
print("Gerado %s (%dx%d)" % (SAIDA, atlas.width, atlas.height))
