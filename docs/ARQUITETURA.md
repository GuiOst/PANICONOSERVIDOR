# Arquitetura — Pânico no Servidor (Etapas 1, A e B)

## Estrutura de pastas

```
res://
├── project.godot            configuração do projeto (InputMap, autoloads, camadas de física)
├── config/network.cfg       endereço do relay e App ID do NodeTunnel (não é segredo)
├── addons/nodetunnel/       extensão NodeTunnel (relay para jogar pela internet; MIT)
├── default_bus_layout.tres  barramentos de áudio: Master, SFX, Ambience
├── export_presets.cfg       predefinição de exportação "Windows Desktop"
├── icon.svg                 ícone do projeto
├── scenes/
│   ├── main/main.tscn               a partida (monta os jogadores)
│   ├── player/player.tscn           jogador
│   ├── environment/facility_level.tscn   a fase (Setor B-2)
│   ├── environment/props/*.tscn     objetos reutilizáveis (caixas, tambores, luminárias...)
│   ├── interactables/industrial_door.tscn  porta interativa
│   └── ui/                          main_menu.tscn (cena inicial), hud.tscn, pause_menu.tscn, horror_theme.tres
├── scripts/
│   ├── main/        main.gd
│   ├── player/      player.gd, player_look.gd, flashlight.gd, footsteps.gd
│   ├── interaction/ interactable.gd, interactor.gd, door.gd, breaker_switch.gd, inspectable.gd
│   ├── environment/ ceiling_lamp.gd, emergency_light.gd, kill_zone.gd
│   ├── network/     network_manager.gd (autoload "Net")
│   ├── ui/          main_menu.gd, hud.gd, pause_menu.gd, crosshair.gd
│   └── systems/     game_settings.gd, game_manager.gd, audio_library.gd,
│                    graphics_quality.gd, looping_sound_3d.gd, ambience_player.gd
├── assets/
│   ├── materials/   materiais compartilhados (.tres)
│   ├── textures/    texturas procedurais (PNG) + ícones da interface (SVG)
│   ├── audio/       footsteps/<superfície>/, doors/, ambience/, creature/, interactions/, ui/
│   │                (créditos em assets/audio/CREDITOS_AUDIO.md)
│   ├── fonts/       DejaVu Sans Mono (+ licença)
│   ├── environment/ facility_environment.tres (névoa, SSAO, glow, tonemap)
│   └── models/      (vazio: reservado para modelos 3D futuros)
├── tools/           ferramentas de desenvolvimento (NÃO entram no .exe)
│   ├── build_scenes.gd      gera props, porta e fase por código
│   ├── tests/smoke_test.gd, audio_test.gd   testes automáticos
│   ├── tests/net_test.gd + run_net_test.sh  teste de rede com várias instâncias
│   └── generators/*.py      geram texturas e sons
└── docs/            esta documentação
```

## Quem faz o quê

| Peça | Responsabilidade | Conhece |
|---|---|---|
| `GameSettings` (autoload) | preferências + salvar/carregar `user://settings.cfg` | nada do jogo |
| `GameManager` (autoload) | pausa (online: só um menu, o mundo não para), mouse, reiniciar, voltar ao menu, sair | a árvore de cenas e `Net` |
| `Net` (autoload) | conexão LAN/relay, sala, lista de jogadores, início/fim da partida, validações do host, repasse de posições | jogadores (por nome `P<id>`) e o contrato `Interactable` |
| `main_menu.gd` | menu principal, tela Multiplayer, sala (lobby), créditos | `Net`, `GameSettings` |
| `main.gd` | cria os jogadores (1 offline; um por conectado online), conecta o jogador local ↔ HUD, trata queda do mapa | Player, HUD, `Net` |
| `Player` | física: andar, correr, pular, gravidade | seus nós filhos |
| `PlayerLook` (Head) | mouse, limite vertical, FOV, balanço | Player |
| `Flashlight` | ligar/desligar, feixe, balanço do feixe | nada |
| `Interactor` | raio, alvo atual, texto, tecla E | apenas o contrato `Interactable` |
| `Interactable` | contrato base de interação | nada |
| `Door` | estado da porta, animação, sons, anti-esmagamento | seu Interactable |
| `BreakerSwitch` | liga circuitos de luz por grupo | grupo `circuit_storage` |
| `CeilingLamp` | ligada/desligada/piscando | seus nós filhos |
| `HUD` / `PauseMenu` | interface | GameManager / GameSettings |

Não há dependências circulares: o jogador não conhece a HUD, e a HUD não conhece o
jogador. Quem liga os dois é `main.gd`, através de **sinais**:

```
Interactor.prompt_changed(text)     ──► HUD.set_prompt
Interactor.feedback_message(text)   ──► HUD.show_feedback
Flashlight.toggled(is_on)           ──► HUD.set_flashlight
GameManager.pause_changed(paused)   ──► PauseMenu / HUD
GameSettings.settings_changed       ──► GraphicsQuality / PlayerLook
KillZone.player_fell(body)          ──► main.gd (respawn)
```

## Áudio (Etapa A)

**Barramentos** (`default_bus_layout.tres`): Master → SFX, Ambience, Creature, UI. Cada um tem
um controle de volume no menu de Opções (Geral, Efeitos, Ambiente, Criatura, Interface).

**Passos** (`scripts/player/footsteps.gd`, nó `Footsteps` do jogador, AudioStreamPlayer3D):
- o ritmo vem da distância percorrida (passo a cada 0,78 m andando e 1,2 m correndo); parado ou no ar não há passos;
- caminhada e corrida usam conjuntos de gravações diferentes;
- a superfície vem do chão real, por um raio para baixo:
  1. uma `SurfaceZone` (Area3D na camada 4), por exemplo a poça d'água;
  2. o metadado `surface` no `CollisionShape3D` atingido (ex.: a chapa da sala técnica = `metal`);
  3. o metadado `surface` no corpo físico;
  4. se nada disso existir, `concrete`;
- não repete as duas últimas variações e varia a afinação em ±5%;
- o volume acompanha a velocidade real;
- emite `step_played(surface, running, loudness_db)`, que o monstro usará para "ouvir" passos.

Para marcar um piso novo: selecione o `CollisionShape3D` no editor → Inspetor → *Metadados* →
adicione `surface` (String) = `metal`, `wet` ou `concrete`. Para uma área sobre outro piso
(grade, poça), use uma `SurfaceZone`.

**Porta** (`scripts/interaction/door_audio.gd`, nó `Panel/DoorSounds`): a porta emite eventos e o componente de som reage.

| Evento da porta | Som |
|---|---|
| começa a abrir estando fechada | trinco na hora; rangido 0,12 s depois, quando a folha "solta" |
| começa a fechar / inverte no meio | rangido do novo sentido (o anterior some em 0,18 s) |
| chega totalmente aberta | batida surda no batente |
| chega totalmente fechada (estado CLOSED) | batida pesada; nunca antes |
| bloqueada por um jogador | o rangido some |
| trancada | maçaneta forçada |

Dois players 3D presos à folha (`Mechanism` na maçaneta, `Hinge` na dobradiça), então o som
se move com a porta e é atenuado pela distância.

**Configuração central:** todos os caminhos ficam em `scripts/systems/audio_library.gd`. Qualquer
som ausente vira silêncio, sem erro.

## Camadas de física

| Camada | Nome | Quem está nela |
|---|---|---|
| 1 | world | paredes, chão, objetos sólidos, folha das portas |
| 2 | player | jogadores |
| 3 | interactable | áreas de interação (raio do E) |
| 4 | surface_zone | zonas de superfície para os passos (poças, grades) |

O raio de interação enxerga as camadas 1 e 3. Por isso uma parede (1) na frente de um
objeto (3) bloqueia a interação: nunca se interage através de paredes.

## Decisões importantes
- **Porta sem RigidBody:** a folha é um `AnimatableBody3D` girado por um valor 0–1
  (`_progress`). É determinística, pode inverter no meio do movimento e nunca trava. Antes
  de cada passo, uma consulta física verifica se a folha vai encostar num jogador. Se ela
  estiver fechando, para e reabre (como portas com sensor).
- **Sons por caminho, não por arrastar no Inspector:** um arquivo ausente não deixa a cena com
  referência quebrada. `AudioLibrary.load_stream()` retorna `null` e nada toca.
- **Fase gerada por código e salva como `.tscn`:** `tools/build_scenes.gd` monta a fase com
  medidas exatas. O resultado é uma cena comum, editável no editor. **Atenção:** rodar o
  construtor de novo sobrescreve edições manuais feitas nessas cenas.
- **Texturas triplanares:** os blocos não precisam de UVs, e as paredes ficam contínuas sem emendas.
- **Luzes desligadas = invisíveis:** a lanterna e as lâmpadas apagadas usam `visible = false`,
  que custa zero no render. Processos contínuos (`_process`) só rodam quando necessários (lâmpada
  piscando, porta se movendo, balanço da lanterna ligada).

## Desempenho (alvo: RTX 3050 6 GB · Ryzen 7 5700G · 16 GB · 1080p)

**Não medido no seu hardware.** Nenhuma medida de FPS foi feita aqui, porque o ambiente de
desenvolvimento não tem placa de vídeo. A cena é leve:
- cerca de 330 nós na fase; materiais compartilhados (32 arquivos `.tres`); texturas de 512–1024 px com compressão de GPU;
- 8 luminárias (1 queimada; sombras ligadas em Média/Alta) + lanterna com sombra + 4 luzes de emergência sem sombra;
- névoa volumétrica, SSAO e glow (desligados no preset **Baixa**).

Se o FPS ficar abaixo do esperado, os maiores custos são, em ordem:
1. **Névoa volumétrica.** Desligue usando a qualidade Baixa, ou reduza em `graphics_quality.gd`.
2. **Sombras das luminárias.** Desligue usando a qualidade Baixa, ou reduza o *Atlas de sombras*
   em Configurações do Projeto → Renderização → Luzes e Sombras.
3. **SSIL** (só no preset Alta).
4. **Resolução 3D:** o preset Baixa já renderiza a 75% com FSR.

Para medir: com o jogo rodando pelo editor, abra **Depurador → Monitores** (FPS, tempo de
quadro, draw calls) ou **Depurador → Profiler Visual**.

## Preparação para as próximas etapas

### Multiplayer (Etapa B — implementado)
Veja a seção "Multiplayer" logo abaixo.

### Monstros
- Crie uma camada de física 4 ("enemy"). A consulta anti-esmagamento da porta (`collision_mask`)
  pode incluí-la.
- Para navegação, adicione um `NavigationRegion3D` à fase. A geometria em blocos simples gera
  uma malha de navegação limpa.
- Luzes já têm `set_powered()`. Eventos como "monstro desliga a energia" só precisam chamar o grupo de luzes.
- A lanterna tem `has_power()`: ponto de entrada para o sistema de bateria.
- `AudioLibrary` centraliza os sons: basta adicionar rugidos e passos de monstros como novas constantes.


## Multiplayer (Etapa B)

### Conexão
| Modo | Tecnologia | Código da sala |
|---|---|---|
| Rede local | ENet direto (UDP, porta 24565) | IP:porta do host |
| Internet | NodeTunnel (relay público gratuito; ninguém abre portas) | código curto gerado pelo relay (ex.: `E4XZN`) |

Os dois modos usam a MESMA lógica de jogo: o `Net` instala o "peer" escolhido em
`multiplayer.multiplayer_peer` e o resto não sabe a diferença.

### Fluxo de uma partida
```
menu → Net.create_lan_room()/create_online_room()   (host)
     → Net.join_lan()/join_online()                  (convidados)
convidado conectado → _rpc_register(nome, versão) → host valida (versão, sala cheia, partida em andamento)
host → _rpc_lobby_state(lista) → todos atualizam a sala
host clica Iniciar → _rpc_load_game → todos carregam main.tscn
cada um monta os jogadores e avisa → _rpc_client_ready → host → _rpc_begin → partida liberada
sair: _rpc_goodbye (aviso imediato) + queda detectada por "batimento" (sem resposta em 10 s)
host sai → todos voltam ao menu com o motivo (não há troca de host)
```

### Quem manda em quê
| Assunto | Quem decide | Como |
|---|---|---|
| Entrar na sala | host | versão igual, máximo 6, só antes de começar |
| Movimento | cada jogador move o próprio corpo | envia posição/rotação/velocidade 20×/s ao host; o host confere se é plausível (velocidade, teletransporte, valores inválidos) e repassa aos outros. Se não for, devolve o jogador à última posição válida |
| Jogadores remotos | — | guardam "fotos" com hora de chegada e são desenhados 100 ms no passado, interpolando entre duas fotos (movimento suave mesmo com pacotes irregulares) |
| Interações (E) | host | `Interactor` → `Net.request_interact()` → host confere: número de sequência (sem duplicados), intervalo mínimo, distância real do jogador, `can_interact` e tempo de recarga → manda **todos** executarem `interact_networked()` na mesma ordem |
| Sentido da porta | host | `get_net_params()` (a porta escolhe abrir para longe de quem abriu) |
| Porta bloqueada por alguém | host | só o host reabre a porta; ele envia o estado completo (`apply_net_state`) para todos e confirma ao terminar cada movimento |
| Mensagens ("Trancada.") | — | aparecem só para quem interagiu (o HUD está ligado apenas ao jogador local) |

Nomes dos jogadores na cena: `Players/P<id>` (o mesmo em todos os computadores). O host é sempre o id 1.

### Adicionar algo sincronizado no futuro
- **Objeto interativo simples** (efeito igual para todos): nada a fazer. Ele já passa pelo host.
- **Precisa de um dado decidido pelo host** (ex.: sorteio): defina `net_params_provider` ou sobrescreva
  `get_net_params()` e leia `last_net_params` dentro de `_on_interact`.
- **Tem estado que pode divergir** (ex.: gerador com combustível): o host chama
  `Net.broadcast_object_state(objeto, {...})` e o objeto implementa `apply_net_state(estado)`.
- **Monstro (Etapa F):** deve rodar a IA só no host e enviar a posição como os jogadores
  (mesmo esquema de fotos e interpolação).
