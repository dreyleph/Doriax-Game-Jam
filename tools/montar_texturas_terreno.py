# montar_texturas_terreno.py
# Gera as texturas do terreno (assets/Terreno/) a partir das imagens em
# assets/AssetsPlataforms/ (assets gratuitos escolhidos pela equipe). Os
# originais nao sao alterados.
#
#   terreno_meio.png  128x640  topo de pedras (Tile_02) + terra (Tile_12), repete na horizontal
#   terreno_esq.png    32x640  borda esquerda  (as imagens atuais nao tem borda lateral:
#   terreno_dir.png    32x640  borda direita    usam a mesma coluna do meio)
#   andaime.png       252x64   escada (2.png) deitada e reduzida a metade = piso de andaime
#
# O LevelGenerator recorta essas imagens (setTextureRect) no tamanho de cada
# chao/bloco/plataforma, entao nao e preciso uma imagem por tamanho.
# Rode na pasta do projeto: python tools/montar_texturas_terreno.py  (requer Pillow)
import os
from PIL import Image

RAIZ = os.path.join(os.path.dirname(__file__), "..", "assets")
ORIGEM = os.path.join(RAIZ, "AssetsPlataforms")
SAIDA = os.path.join(RAIZ, "Terreno")
T = 32           # lado do tile
LINHAS = 20      # 640 px de altura (o chao tem 600)

topo = Image.open(os.path.join(ORIGEM, "Tile_02.png")).convert("RGBA")
terra = Image.open(os.path.join(ORIGEM, "Tile_12.png")).convert("RGBA")

def coluna(larg_tiles):
    img = Image.new("RGBA", (larg_tiles * T, LINHAS * T), (0, 0, 0, 0))
    for c in range(larg_tiles):
        img.alpha_composite(topo, (c * T, 0))
        for r in range(1, LINHAS):
            img.alpha_composite(terra, (c * T, r * T))
    return img

os.makedirs(SAIDA, exist_ok=True)
coluna(4).save(os.path.join(SAIDA, "terreno_meio.png"))
coluna(1).save(os.path.join(SAIDA, "terreno_esq.png"))
coluna(1).save(os.path.join(SAIDA, "terreno_dir.png"))

# Escada 128x585 em pe: recorta um trecho que repete sem emenda (do primeiro
# degrau, y=32, ate o oitavo, y=535 -> 7 degraus), deita (trilhos viram o
# topo e a base do piso) e reduz a metade (64 px de altura).
escada = Image.open(os.path.join(ORIGEM, "2.png")).convert("RGBA")
trecho = escada.crop((0, 32, escada.width, 535))
deitada = trecho.rotate(90, expand=True)
andaime = deitada.resize((deitada.width // 2, deitada.height // 2), Image.NEAREST)
andaime.save(os.path.join(SAIDA, "andaime.png"))
print("Texturas geradas em assets/Terreno/ (andaime %dx%d)" % andaime.size)
