# montar_icones_hud.py
# Gera os icones do HUD (assets/HUD/) a partir das artes do Edu feitas no
# Aseprite (.ase), que a engine nao le:
#   vida_tipu.png     <- assets/Tipu.ase  (garrafa de Tipu, uma por vida; inclinada para a direita)
#   municao_slug.png  <- assets/Slug.ase  (cartucho, um por disparo da Escopeta)
# Le o primeiro quadro do arquivo, recorta, (inclina) e reduz para o tamanho
# do HUD. Os originais nao sao alterados. Se o Edu exportar PNG, tambem serve
# (troque o nome em ICONES).
#
# Rode na pasta do projeto: python tools/montar_icones_hud.py  (requer Pillow)
import os, struct, zlib
from PIL import Image

ASSETS = os.path.join(os.path.dirname(__file__), "..", "assets")
SAIDA = os.path.join(ASSETS, "HUD")
# origem -> (arquivo gerado, inclinacao em graus (topo para a direita), altura final em px)
ICONES = {
    "Tipu.ase": ("vida_tipu.png", 15, 44),
    "Slug.ase": ("municao_slug.png", 0, 22),
}

def ler_ase(caminho):
    """Primeiro quadro de um .ase em modo RGBA (camadas visiveis, opacidade normal)."""
    d = open(caminho, "rb").read()
    _, magic, quadros, w, h, prof = struct.unpack_from("<IHHHHH", d, 0)
    if magic != 0xA5E0 or prof != 32:
        raise SystemExit("%s: so sei ler arquivos do Aseprite em modo RGBA (exporte um PNG)" % caminho)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    camadas = []   # visibilidade de cada camada
    off = 128
    tam, _, antigos, _ = struct.unpack_from("<IHHH", d, off)
    novos = struct.unpack_from("<I", d, off + 12)[0]
    p = off + 16
    for _ in range(novos or antigos):
        ctam, tipo = struct.unpack_from("<IH", d, p)
        if tipo == 0x2004:   # camada
            flags = struct.unpack_from("<H", d, p + 6)[0]
            camadas.append(flags & 1 == 1)
        elif tipo == 0x2005:  # cel
            camada, x, y, opac, ctipo = struct.unpack_from("<HhhBH", d, p + 6)
            if ctipo in (0, 2) and (camada >= len(camadas) or camadas[camada]):
                cw, ch = struct.unpack_from("<HH", d, p + 6 + 16)
                dados = d[p + 6 + 20:p + ctam]
                if ctipo == 2:
                    dados = zlib.decompress(dados)
                cel = Image.frombytes("RGBA", (cw, ch), dados[:cw * ch * 4])
                if opac < 255:
                    cel.putalpha(cel.getchannel("A").point(lambda a: a * opac // 255))
                img.alpha_composite(cel, (x, y))
        p += ctam
    return img

def abrir(caminho):
    if caminho.lower().endswith(".ase") or caminho.lower().endswith(".aseprite"):
        return ler_ase(caminho)
    return Image.open(caminho).convert("RGBA")

os.makedirs(SAIDA, exist_ok=True)
for origem, (destino, inclinacao, altura) in ICONES.items():
    img = abrir(os.path.join(ASSETS, origem))
    img = img.crop(img.getbbox())
    # aumenta 4x (sem borrar), gira suave se precisar e reduz no fim
    grande = img.resize((img.width * 4, img.height * 4), Image.NEAREST)
    if inclinacao:
        grande = grande.rotate(-inclinacao, resample=Image.BICUBIC, expand=True)
        grande = grande.crop(grande.getbbox())
    escala = altura / grande.height
    final = grande.resize((max(1, round(grande.width * escala)), altura), Image.LANCZOS)
    final.save(os.path.join(SAIDA, destino))
    print("%-9s -> HUD/%-17s %dx%d (inclinado %d graus)" % (origem, destino, final.width, final.height, inclinacao))
