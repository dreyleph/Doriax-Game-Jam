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
| Pular | Espaço ou K |
| Descer da plataforma | S / ↓ + pulo |
| Atirar | J |
| Mirar para cima | segurar W / ↑ (andando = diagonal) |
| Mirar para baixo | no ar, segurar S / ↓ (andando = diagonal) |

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

## Vidas e pontuação (provisório)
- Começa com 3 vidas e 0 pontos. Cada inimigo abatido vale 500 pontos.
- Morrer (encostar em inimigo ou cair do mapa) tira 1 vida e metade dos pontos; o jogador renasce no último chão seguro com 2 s de invencibilidade.
- Sem vidas: GAME OVER e a fase recomeça do zero após 3 s.
- Tudo ajustável no Inspector do Jogador (vidas, penalidade, tempos) e do inimigo (pontos).

## Mapa procedural (protótipo)
- Cada tela (1280 px) é montada com **4 módulos de 320 px** sorteados de `scripts/level/Chunks.lua` (buracos, plataformas, degraus, caixas, grupos de inimigos...). A corrida começa sempre por uma tela segura.
- Regras: nunca o mesmo módulo duas vezes seguidas, no máximo 1 módulo plano por tela, módulos difíceis só depois de algumas telas.
- Inimigos: um mínimo garantido por tela (2 no início, +1 a cada 3 telas, até 6) e os demais pontos por chance crescente. Tudo ajustável no **Gerador**.
- A câmera não volta e o jogador não sai pela esquerda da tela (estilo Metal Slug).
- A semente aparece no log ("Corrida gerada com semente N"); coloque-a em **Semente** no Gerador para repetir a mesma corrida.
- Para criar um módulo novo, adicione uma tabela em `Chunks.lua` (é um script: pode editar com o editor aberto). As regras para ele encaixar com qualquer vizinho estão no topo do arquivo.

## Estado atual
- Gráficos são retângulos provisórios.
