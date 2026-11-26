# montar_atlas_inimigo.py
# Junta as sprite sheets de cada inimigo numa unica imagem (atlas), uma
# animacao por linha, como o atlas do jogador
# (ver montar_atlas_jogador.py: trocar de textura em jogo faz o sprite "bugar").
#   assets/Enemy1/ -> Inimigo-Atlas.png   (soldado,  scripts/enemy/EnemyAnimations.lua)
#   assets/Enemy2/ -> Inimigo2-Atlas.png  (atirador, scripts/enemy/EnemyAnimations2.lua)
#
# Quando a arte mudar ou chegar sheet nova: edite ATLAS, rode
#   python tools/montar_atlas_inimigo.py
# e ajuste "first" (linha * COLUNAS) no EnemyAnimations correspondente.
# Requer Pillow (pip install pillow).
import os
from PIL import Image

ASSETS = os.path.join(os.path.dirname(__file__), "..", "assets")
QUADRO = 128
COLUNAS = 8
ATLAS = [
    ("Enemy1", "Inimigo-Atlas.png", [
        ("Runing-Sheet.png", 8),    # linha 0 -> first = 0   andando / correndo
        ("Idle-Sheet.png", 1),      # linha 1 -> first = 8   parado
    ]),
    ("Enemy2", "Inimigo2-Atlas.png", [
        ("Runnig-Sheet2.png", 8),   # linha 0 -> first = 0   andando / correndo
        ("Idle-Sheet2.png", 1),     # linha 1 -> first = 8   parado
        ("Shooting.png", 4),        # linha 2 -> first = 16  atirando
    ]),
]

for pasta, saida, linhas in ATLAS:
    dir_ = os.path.join(ASSETS, pasta)
    atlas = Image.new("RGBA", (COLUNAS * QUADRO, len(linhas) * QUADRO), (0, 0, 0, 0))
    for linha, (arquivo, quadros) in enumerate(linhas):
        img = Image.open(os.path.join(dir_, arquivo)).convert("RGBA")
        if quadros > COLUNAS or img.width < quadros * QUADRO or img.height < QUADRO:
            raise SystemExit("%s/%s: tamanho inesperado %dx%d" % (pasta, arquivo, img.width, img.height))
        atlas.paste(img.crop((0, 0, quadros * QUADRO, QUADRO)), (0, linha * QUADRO))
    atlas.save(os.path.join(dir_, saida))
    print("Gerado %s/%s (%dx%d)" % (pasta, saida, atlas.width, atlas.height))
