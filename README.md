# Doriax Game Jam – 184X

Jogo de plataforma run and gun 2D inspirado em Metal Slug, ambientado na São Cristóvão (Sergipe) dos anos 184X.

- Engine: [Doriax](https://github.com/doriaxengine/doriax) v0.8.5
- Scripts: Lua (`scripts/`)

## Como abrir
1. Abra a pasta do projeto no Doriax Editor.
2. Abra a cena **Fase Teste** e aperte Play.

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
| `Fase Teste.scene` | cena de teste (chão, plataformas, jogador, inimigos, câmera) |
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

## Estado atual
- Gráficos são retângulos provisórios.
