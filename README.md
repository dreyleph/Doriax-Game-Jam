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
| `scripts/enemy/Enemy.lua` | inimigo comum (patrulha, dano por contato) |
| `scripts/projectile/Projectile.lua` | projétil do jogador |
| `HUD.scene` | cena de UI (pontos, vidas, GAME OVER) anexada como cena filha da fase |
| `scripts/game/GameState.lua` | vidas e pontuação da partida |
| `scripts/ui/HUD.lua` | atualiza os textos do HUD |
| `scripts/camera/CameraFollow.lua` | câmera lateral |
| `scripts/game/Combat.lua` | categorias de colisão e regras de combate compartilhadas |
| `scripts/itens/Itens.lua` | itens que caem dos inimigos (chances, cores e efeitos) |

## Vidas e pontuação (provisório)
- Começa com 3 vidas e 0 pontos. Cada inimigo abatido vale 500 pontos.
- Morrer (encostar em inimigo ou cair do mapa) tira 1 vida (os pontos são mantidos); o jogador renasce na superfície segura mais próxima com 2 s de invencibilidade.
- Sem vidas: GAME OVER e a fase recomeça do zero após 3 s.
- Tudo ajustável no Inspector do Jogador (vidas, tempos) e do inimigo (pontos).

## Personagem (John Drinkwater)
- Sheets em `assets/John Drinkwater/` (quadros de 128×128, virado para a direita). Mapeamento em `scripts/player/PlayerAnimations.lua`:
  parado = 1º quadro da `IdleShooting-Sheet`, parado atirando = `IdleShooting-Sheet` (5 quadros); a `Idle-Sheet` antiga não é usada, andando = `Running-Sheet`, andando atirando = `Running&Shooting-Sheet`.
  O jogo usa um atlas único, `assets/John Drinkwater/Jogador-Atlas.png`, gerado a partir dessas sheets por `python tools/montar_atlas_jogador.py` (rode de novo quando a arte mudar). Trocar de imagem durante o jogo fazia o personagem sumir/"bugar" por alguns quadros.
- Ainda sem arte (usam uma animação reserva): pulo, pulo atirando e reviver.
- Ao morrer, o jogador reaparece na superfície mais próxima (chão, bloco ou plataforma), longe da borda e dentro da tela; fica ~1 s parado revivendo e depois volta ao controle, ainda invencível por 2 s.

## Itens (provisório)
Cada inimigo abatido sorteia no máximo 1 item; o jogador pega encostando. O item some após 10 s (pisca antes).

| Item | Cor | Chance | Efeito |
|---|---|---|---|
| Pisa Macio | amarelo | 5% | +1 vida (até o máximo inicial) |
| Charuto | preto | 1% | 10 s de tiro automático e rápido segurando J |
| Caranguejo | laranja | 0,1% | recupera todas as vidas e dano x2 por 10 s |

Os efeitos temporários acabam ao morrer. Chances, cores e durações ficam no topo de `scripts/itens/Itens.lua`.

## Mapa procedural (protótipo)
- Cada tela (1280 px) é montada com **4 módulos de 320 px** sorteados de `scripts/level/Chunks.lua` (buracos, plataformas, degraus, caixas, grupos de inimigos...). A corrida começa sempre por uma tela segura.
- Regras: nunca o mesmo módulo duas vezes seguidas, no máximo 1 módulo plano por tela, módulos difíceis só depois de algumas telas.
- Inimigos: um mínimo garantido por tela (2 no início, +1 a cada 3 telas, até 6) e os demais pontos por chance crescente. Tudo ajustável no **Gerador**.
- A câmera não volta e o jogador não sai pela esquerda da tela (estilo Metal Slug).
- A semente aparece no log ("Corrida gerada com semente N"); coloque-a em **Semente** no Gerador para repetir a mesma corrida.
- **Texturas do terreno**: chão e blocos = pedras com terra (`Tile_02` topo, `Tile_12` terra); plataformas = andaime (escada `2.png` deitada). Originais em `assets/AssetsPlataforms/` (assets gratuitos); as texturas usadas no jogo ficam em `assets/Terreno/` e são geradas por `python tools/montar_texturas_terreno.py`. O gerador recorta essas imagens no tamanho de cada peça; a colisão continua num corpo invisível separado (o desenho do andaime tem 64 px e fica pendurado abaixo dos 32 px de colisão).
- Para criar um módulo novo, adicione uma tabela em `Chunks.lua` (é um script: pode editar com o editor aberto). As regras para ele encaixar com qualquer vizinho estão no topo do arquivo.

## Estado atual
- Terreno com texturas de teste (assets gratuitos); inimigos e itens ainda são retângulos provisórios. A `Fase Teste` mantém os blocos antigos da cena.
