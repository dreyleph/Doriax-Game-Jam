# montar_atlas_jogador.py
# Junta as sprite sheets do John Drinkwater numa unica imagem (atlas), uma
# animacao por linha. O jogo usa so essa imagem e troca apenas o pedaco
# mostrado (setTextureRect).
#
# Por que: trocar de textura em jogo (setTexture) faz a Doriax descartar a
# imagem anterior e carregar a nova do disco; enquanto carrega, o sprite fica
# sem desenho por alguns quadros (o personagem "bugava" ao comecar/parar de
# andar ou atirar).
#
# Quando a arte mudar ou chegar sheet nova: adicione/edite em LINHAS abaixo,
# rode  python tools/montar_atlas_jogador.py  na pasta do projeto e ajuste
# "first" (linha * COLUNAS) em scripts/player/PlayerAnimations.lua.
# Requer Pillow (pip install pillow).
import os
from PIL import Image

PASTA = os.path.join(os.path.dirname(__file__), "..", "assets", "John Drinkwater")
QUADRO = 128
COLUNAS = 8
# (arquivo, quantidade de quadros) - a ordem define a linha no atlas
LINHAS = [
    ("IdleShooting-Sheet.png", 5),       # linha 0 -> first = 0   parado atirando
    ("Running-Sheet.png", 8),            # linha 1 -> first = 8   correndo
    ("Running&Shooting-Sheet.png", 8),   # linha 2 -> first = 16  correndo atirando
    ("Idle-Sheet.png", 7),               # linha 3 -> first = 24  parado (quadro 0) + tomando dano (1 a 6)
    ("Jumping-Sheet.png", 3),            # linha 4 -> first = 32  pulo
]
SAIDA = "Jogador-Atlas.png"

atlas = Image.new("RGBA", (COLUNAS * QUADRO, len(LINHAS) * QUADRO), (0, 0, 0, 0))
for linha, (arquivo, quadros) in enumerate(LINHAS):
    img = Image.open(os.path.join(PASTA, arquivo)).convert("RGBA")
    if quadros > COLUNAS or img.width < quadros * QUADRO or img.height < QUADRO:
        raise SystemExit("%s: tamanho inesperado %dx%d" % (arquivo, img.width, img.height))
    atlas.paste(img.crop((0, 0, quadros * QUADRO, QUADRO)), (0, linha * QUADRO))
atlas.save(os.path.join(PASTA, SAIDA))
print("Gerado %s (%dx%d)" % (SAIDA, atlas.width, atlas.height))
