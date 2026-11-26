# Doriax Game Jam – 184X

Jogo de plataforma run and gun 2D inspirado em Metal Slug, ambientado na São Cristóvão (Sergipe) dos anos 184X.

- Engine: [Doriax](https://github.com/doriaxengine/doriax) v0.8.5
- Scripts: Lua (`scripts/`)

## Como abrir
1. Abra a pasta do projeto no Doriax Editor.
2. Aperte Play: a cena inicial é a **Corrida** (mapa gerado a cada partida).
   A **Fase Teste** (mapa fixo) continua no projeto para testar mecânicas isoladas.

> Feche o editor antes de editar `.scene`, `.bundle` ou `project.yaml` fora dele: o editor grava por cima a versão que tem na memória. Scripts `.lua` podem ser editados com o editor aberto.

## Controles
| Ação | Teclas |
|---|---|
| Andar | A / D ou setas ← → |
| Pular | Espaço |
| Descer da plataforma | S / ↓ + pulo |
| Atirar | J |
| Arma secundária (Escopeta, se tiver pego) | K |
| Faca (corpo a corpo, mesma mira dos tiros) | L |
| Dash (na direção segurada; sem direção = para frente) | E |
| Mirar para cima | segurar W / ↑ (andando = diagonal) |
| Mirar para baixo | no ar, segurar S / ↓ (andando = diagonal) |

Matar um inimigo com a faca zera a espera de 1 s do dash e, se for no ar, libera um pulo extra (até encostar no chão).

**Rastro do dash (afterimage):** durante o impulso do dash ficam para trás cópias azuladas e transparentes do John (mesmo quadro da animação), a primeira no ponto onde o dash começou; cada uma some em 0,3 s. As cópias são criadas uma vez no início e reusadas (sem engasgo). Propriedades do Jogador: `Dash: rastro (afterimage)` (liga/desliga), `Dash: intervalo entre copias do rastro (s)`, `Dash: quanto cada copia demora para sumir (s)` e `Dash: opacidade inicial do rastro (0-1)`.
A faca dá **2 de dano** (mata qualquer inimigo num golpe); a área de acerto é feita de blocos de 56 px (frente: 1 bloco; cima/baixo: 3). O golpe mostra um efeito de corte (pacote `assets/SLASH VFX/`: arco largo para a frente, arco fino para cima/baixo) no tamanho da área de acerto. As sheets usadas ficam em `assets/VFX/` e são geradas por `python tools/montar_vfx_faca.py`.

**Rebater tiros:** enquanto o golpe da faca dura, um tiro inimigo que encostar na área do golpe volta pelo mesmo caminho (na direção de quem atirou), 1,5x mais rápido e amarelo. O tiro rebatido não machuca o John e dá o dano da faca no inimigo que acertar. Propriedades do Jogador: `Faca: rebate tiros inimigos` (liga/desliga) e `Faca: velocidade do tiro rebatido (x)`. Os tiros inimigos agora têm 16 px.

## Estrutura
| Caminho | Conteúdo |
|---|---|
| `Corrida.scene` | cena principal: câmera, jogador e gerador do mapa procedural |
| `Fase Teste.scene` | mapa fixo para testar mecânicas |
| `bundles/Inimigo.bundle` | inimigo comum, criado pelo gerador ao longo do caminho |
| `scripts/level/Chunks.lua` | módulos do mapa (chão, buracos, blocos, plataformas, pontos de inimigo) |
| `scripts/level/LevelGenerator.lua` | sorteia módulos, monta as telas à frente e remove as que ficaram para trás |
| `scripts/game/Run.lua` | estado da corrida (borda da câmera) |
| `bundles/Projetil.bundle` | projétil, criado pelo script ao atirar |
| `scripts/player/Player.lua` | movimento, pulo, descer de plataforma, tiro |
| `scripts/enemy/Enemy.lua` | inimigo comum (anda à toa, persegue o jogador que vê, dano por contato) |
| `scripts/projectile/Projectile.lua` | projétil do jogador |
| `HUD.scene` | cena de UI (pontos, vidas, GAME OVER) anexada como cena filha da fase |
| `scripts/game/GameState.lua` | vidas e pontuação da partida |
| `scripts/ui/HUD.lua` | atualiza o HUD: fonte pixelada `assets/Fonte/BoldPixels.ttf` e pontos totais e distância, vidas como garrafas de Tipu e munição da Escopeta como cartuchos (ícones em `assets/HUD/`, gerados de `assets/Tipu.ase` e `assets/Slug.ase` por `python tools/montar_icones_hud.py`) |
| `scripts/camera/CameraFollow.lua` | câmera lateral |
| `scripts/game/Combat.lua` | categorias de colisão e regras de combate compartilhadas |
| `scripts/itens/Itens.lua` | itens que caem dos inimigos (chances, cores e efeitos) |

## Vidas, pontuação e progressão
- Começa com 3 vidas. Pontos = **abates** (500 por inimigo) **+ distância** (10 pontos por metro; 1 m = 32 px andados para a direita). Durante a corrida, PONTOS mostra só os abates e os metros ficam no canto superior direito; a distância só entra na pontuação no fim: no GAME OVER, PONTOS passa a mostrar o total e aparece o resumo (abates + distância = total).
- Morrer (encostar em inimigo, levar tiro ou cair do mapa) tira 1 vida (pontos e distância são mantidos); o jogador renasce na superfície segura mais próxima com 2 s de invencibilidade.
- Sem vidas: GAME OVER e a corrida recomeça do zero após 3 s.
- **Progressão** (o jogo fica mais difícil quanto mais longe, até ser impossível): 1 inimigo na 1ª tela, +1 a cada 2 telas, até 12 por tela (máximo de 30 vivos); atiradores a partir da 3ª tela (20% → 50%); todos ficam até 80% mais rápidos, se assustam menos, enxergam mais longe e os atiradores atiram mais rápido. Tudo ajustável no **Gerador** (propriedades "Progressão").

## Personagem (John Drinkwater)
- Sheets em `assets/John Drinkwater/` (quadros de 128×128, virado para a direita). Mapeamento em `scripts/player/PlayerAnimations.lua`:
  **parado** = `Idle-Sheet` inteira em loop contínuo a 8 fps (começa assim que ele para e a cabeça não para de mexer); parado atirando = `IdleShooting-Sheet`; andando = `Running-Sheet`; andando atirando = `Running&Shooting-Sheet`; **pulo** = `Jumping-Sheet` (3 quadros, uma vez, o último fica até pousar).
  O jogo usa um atlas único, `assets/John Drinkwater/Jogador-Atlas.png`, gerado a partir dessas sheets por `python tools/montar_atlas_jogador.py` (rode de novo quando a arte mudar). Trocar de imagem durante o jogo fazia o personagem sumir/"bugar" por alguns quadros.
- Ainda sem arte: **dano** (o jogador some na hora ao levar dano; quando a sheet chegar, já há lugar para ela em `PlayerAnimations.lua`), pulo atirando (usa o pulo) e reviver (usa o parado).
- Ao morrer, o jogador reaparece na superfície mais próxima (chão, bloco ou plataforma), longe da borda e dentro da tela; fica ~1 s parado revivendo e depois volta ao controle, ainda invencível por 2 s.

## Inimigos
- **Soldado** (2 de vida): persegue e machuca encostando. **Atirador** (1 de vida, farda vermelha do Enemy2): ao ver o jogador para, mira e atira de tempos em tempos (tiro laranja que passa pelas plataformas e para no chão/blocos); não persegue, só se aproxima devagar. Ao levar um tiro sem morrer, o inimigo pisca e reage.
- Arte do soldado em `assets/Enemy1/` (`Runing-Sheet`, `Idle-Sheet`) → atlas `Inimigo-Atlas.png`, animações em `scripts/enemy/EnemyAnimations.lua`. Arte do atirador em `assets/Enemy2/` (`Runnig-Sheet2`, `Idle-Sheet2`, `Shooting`) → atlas `Inimigo2-Atlas.png`, animações em `scripts/enemy/EnemyAnimations2.lua` (mira parado e toca o disparo a cada tiro). Os dois atlas saem de `python tools/montar_atlas_inimigo.py`. Hitbox 40×104 (igual ao jogador).
- **À toa**: anda devagar (60 px/s, animação a 8 fps) por todo o chão/plataforma onde está, vira nas beiradas e paredes (não cai) e de vez em quando para um pouco.
- **Perseguindo**: se o jogador aparece na frente (até 420 px) ou bem perto atrás (110 px), na mesma altura (até 150 px de diferença), ele para um instante (susto), vira para o jogador e corre atrás (190 px/s, animação a 18 fps). Muda de nível para alcançá-lo: pula para plataformas e blocos (até ~165 px acima, usando uma plataforma do meio se precisar), desce por plataformas atravessáveis, desce de beiradas quando há chão embaixo e pula buracos de até ~180 px. Buraco maior: espera na beirada olhando para o jogador. Desiste se o jogador ficar longe (650 px) por 1,5 s.
- Inimigos que ficam para trás da tela (150 px depois da borda esquerda) são eliminados **sem dar pontos nem item**; os abatidos são liberados da cena logo em seguida (gerador, `cleanupEnemies`).
- Tudo ajustável no Inspector do bundle `Inimigo` (velocidades, alcance da visão, tempos).

## Itens
Cada inimigo abatido sorteia no máximo 1 item; o jogador pega encostando. O item some após 10 s (pisca antes).

| Item | Desenho | Chance | Efeito |
|---|---|---|---|
| Pisa Macio | garrafa (`assets/Itens/pisa_macio.png`) | 10% | +1 vida (até o máximo inicial) |
| Escopeta | mosquete (`assets/Itens/escopeta.png`) | 3% | arma secundária na tecla K: 5 projéteis em leque, alcance curto, 10 disparos (pegar outra recarrega) |
| Charuto | charuto (`assets/Itens/charuto.png`) | 5% | 10 s de tiro automático e rápido segurando J |
| Caranguejo | caranguejo (`assets/Itens/caranguejo.png`) | 0,67% | 15 s de imortalidade e dano x2 |

As imagens de `assets/Itens/` são geradas a partir das artes originais do Edu (`assets/PisaMacio.png`, `Musket.png`, `Kraby1.png`, `Charuto.png`) por `python tools/montar_sprites_itens.py`, já no tamanho do jogo. Os efeitos temporários acabam ao morrer; a arma secundária fica até acabar a munição. Chances, durações e desenhos ficam no topo de `scripts/itens/Itens.lua`.

## Mapa procedural (protótipo)
- Cada tela (1280 px) é montada com **4 módulos de 320 px** sorteados de `scripts/level/Chunks.lua` (buracos, plataformas, degraus, caixas, grupos de inimigos...). A corrida começa sempre por uma tela segura.
- Regras: nunca o mesmo módulo duas vezes seguidas, no máximo 1 módulo plano por tela, módulos difíceis só depois de algumas telas.
- Inimigos: quantidade, tipo e velocidade conforme a progressão (ver acima); primeiro nos pontos de inimigo dos módulos, e o que faltar em lugares sorteados do trecho.
- A câmera não volta e o jogador não sai pela esquerda da tela (estilo Metal Slug).
- A semente aparece no log ("Corrida gerada com semente N"); coloque-a em **Semente** no Gerador para repetir a mesma corrida.
- **Texturas do terreno**: chão e blocos = pedras com terra (`Tile_02` topo, `Tile_12` terra); plataformas = andaime (escada `2.png` deitada). Originais em `assets/AssetsPlataforms/` (assets gratuitos); as texturas usadas no jogo ficam em `assets/Terreno/` e são geradas por `python tools/montar_texturas_terreno.py`. O gerador recorta essas imagens no tamanho de cada peça; a colisão continua num corpo invisível separado (o desenho do andaime tem 64 px e fica pendurado abaixo dos 32 px de colisão).
- Para criar um módulo novo, adicione uma tabela em `Chunks.lua` (é um script: pode editar com o editor aberto). As regras para ele encaixar com qualquer vizinho estão no topo do arquivo.

## Estado atual
- Terreno com texturas de teste (assets gratuitos); itens ainda são retângulos provisórios. A `Fase Teste` mantém os blocos antigos da cena.
