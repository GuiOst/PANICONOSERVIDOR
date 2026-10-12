# Progresso do desenvolvimento — Pânico no Servidor

Última atualização: 12/10/2026 — **Etapa B (multiplayer) implementada e testada com várias instâncias
reais do Godot (rede local e relay). Falta o seu teste entre dois computadores e o token do NodeTunnel.**

## Ordem das etapas
| Etapa | Conteúdo | Situação |
|---|---|---|
| 1 | Protótipo base 3D (movimento, lanterna, porta, cenário, HUD, pausa) | concluída |
| A | Passos e porta com gravações reais; barramentos de áudio | concluída (você aprovou) |
| **B** | **Multiplayer cooperativo (salas, relay, sincronização)** | **implementada; testada aqui com até 7 instâncias; falta o teste entre PCs (veja abaixo)** |
| C | Mapa completo | não iniciada |
| D | Sistema de energia | não iniciada (já existem as bases `set_powered()` e o disjuntor) |
| E | Câmeras de segurança | não iniciada |
| F | Monstro "O Vigia" | não iniciada (os passos já emitem `step_played` para a audição dele) |
| G | Sobrevivência (saúde, stamina, bateria, inventário) | não iniciada (a lanterna já tem `has_power()`) |
| H | Objetivos e fuga | não iniciada |
| I | Polimento visual e sonoro | não iniciada |
| J | Interface completa | adiantada em parte: menu principal, multiplayer, sala e créditos já existem; faltam remapear teclas e o acabamento |

## Etapa B — o que foi feito

### Avaliação das opções (antes de integrar)
| Opção | Resultado |
|---|---|
| **NodeTunnel** (escolhido) | Gratuito, código aberto (MIT), relay público e servidor próprio opcional, compatível com Godot 4.3+. Testado aqui com o servidor de relay oficial compilado do código-fonte. Pede só um token de aplicativo gratuito. **Está em beta.** |
| Ezcha Relay | Exige cadastro como desenvolvedor, e as chaves de API e de assinatura ficam dentro do jogo exportado. Isso viola a regra de não colocar chaves no executável. Rejeitado. |
| noray | Não há servidor público. Hospedar exige um servidor próprio ou abrir portas. Rejeitado. |
| GD-Sync, Steam, W4 | Pagos ou exigem chaves/contas comerciais. Rejeitados. |

### Funcionalidades
- **Menu principal:** Jogar sozinho, Multiplayer, Opções, Créditos e Sair.
- **Multiplayer:**
  - nome configurável (fica salvo);
  - criar ou entrar em sala pela **internet** (código gerado pelo relay) ou pela **rede local** (IP).
- **Sala:**
  - código com botão Copiar;
  - lista de jogadores, com ★ e "(host)", "(você)" e a contagem "N de 6";
  - avisos de entrada e saída;
  - **Iniciar partida** só para o host; os outros veem "aguardando o host".
- **Regras de entrada:**
  - de 2 a 6 jogadores;
  - o 7º é recusado com uma mensagem;
  - ninguém entra no meio da partida;
  - versão diferente do jogo é recusada.
- **Início sincronizado:** todos carregam a fase. Ninguém se move até todos avisarem que estão prontos.
  Quem demorar mais de 30 s é retirado. Esse caso não foi testado: aqui ninguém demorou tanto.
- **Jogadores:**
  - cada um vê os outros com cor própria, visor e nome em cima;
  - movimento suave (interpolação de 100 ms, envio 20×/s);
  - a lanterna e os passos dos outros usam som 3D na posição deles. Isso não foi testado de ouvido.
- **Validações no host:**
  - posição impossível ou "teletransporte" → o jogador volta à última posição válida;
  - interação de longe recusada;
  - pedido repetido ou rápido demais ignorado.
- **Portas, disjuntor e portão:**
  - executados na mesma ordem em todos os PCs, com o sentido da porta decidido pelo host;
  - só o host decide reabrir uma porta que encosta em alguém, e envia a correção a todos;
  - mensagens como "Trancada." aparecem só para quem tentou.
- **Menu Esc online:** o jogo não pausa. Ele só tira o controle de quem abriu o menu.
  Os botões mudam para "Sair da partida", e "Reiniciar" fica escondido.
- **Saídas e quedas:**
  - **cliente sai:** os outros recebem o aviso e o corpo dele some;
  - **host sai:** todos voltam ao menu com o motivo;
  - **queda sem aviso** (internet caiu, jogo fechou): é detectada em cerca de 6 a 12 s;
  - **erros:** IP inválido, sala inexistente, token recusado, relay fora do ar e tempo esgotado têm mensagens claras em português.

## Testes realizados (de verdade)
Cada teste abre **processos separados do Godot** (host e convidados), que se conectam pela rede.
Foram dois transportes:
- **LAN:** ENet por 127.0.0.1;
- **Relay:** o **servidor oficial do NodeTunnel**, compilado do código-fonte e rodando aqui, com os mesmos limites do servidor público.

| Cenário | O que confere | LAN (4.6.3) | Relay (4.6.3) |
|---|---|---|---|
| `main` (2 jogadores) | lista e nomes, início, movimento (diferença ≤ 0,001 m), suavidade, lanterna, porta (mesmo ângulo nos 2), pedido duplicado, porta bloqueada pelo host, mensagem só para quem tentou, disjuntor, teletransporte recusado, interação de longe recusada, menu Esc online, cliente sai, reentrada recusada | 69/69 | 69/69 |
| `ui` (pelos botões) | criar sala, entrar, lista, Iniciar só no host, "Sair da partida", aviso no menu | 18/18 | — |
| `kill` | processo do host morto à força → cliente volta ao menu | 4/4 (11,7 s) | 4/4 (6,8 s) |
| `killclient` | processo do cliente morto → host remove o jogador | 6/6 (11,1 s) | 6/6 (5,9 s) |
| `hostleave` (3 jogadores) | host sai → os 2 voltam ao menu com o motivo | 13/13 | 13/13 |
| `full` (6 + 1) | 6 entram, o 7º é recusado, os 6 jogam e se veem nas posições certas (≤ 0,004 m), tráfego medido | 40/40 | 40/40 |
| `errors` | mensagens de erro de conexão | 2/2 | 6/6 |

- **Total:** 290 verificações OK, 0 falhas no Godot 4.6.3.
- **Godot 4.7.2** (lan main/ui/full + relay main/hostleave/kill): 213/213 OK.
- **Regressão:** `smoke_test` 70/70 e `audio_test` 27/27 nas duas versões.
- **Telas conferidas** em imagem: menu, Multiplayer, sala, Opções e jogadores remotos na fase.

**O que NÃO foi testado (e por quê):**
- **Dois computadores de verdade:** aqui todas as instâncias rodam na mesma máquina. Firewall do Windows,
  Wi-Fi e roteador só aparecem no seu teste. Por isso **ainda não declaro o multiplayer pronto entre PCs**.
- **Relay público `us-east.nodetunnel.io`:** este ambiente não acessa a internet livremente. Também
  não existe token de aplicativo, que só você pode criar. O relay testado foi o mesmo programa oficial
  rodando localmente.
- **Latência real da internet:** localmente o atraso é quase zero. A interpolação foi feita para aguentar
  variação de chegada dos pacotes, mas a sensação com ~150 ms de ping precisa do seu teste.
- **Exportação para Windows com a DLL:** o `.pck` foi exportado e contém a configuração e a extensão.
  O `.exe` final precisa dos modelos de exportação no seu PC.

## Problemas conhecidos (Etapa B)
- **NodeTunnel está em beta:** a compatibilidade pode mudar, e o relay público não tem garantia.
  A rede local não depende dele.
- **Pela internet não dá para expulsar jogadores** (o plugin ainda não permite). As entradas inválidas
  são recusadas antes de conectar.
- **Sem troca de host** (como você pediu) e sem entrar no meio da partida.
- **O corpo dos jogadores é provisório** (cápsula colorida).
- **Grafia do servidor:** o site usa `us-east...` e a documentação usa `us_east...`. Daqui não consegui
  testar qual responde; o tutorial explica como trocar.
- **Teste de rede automático:** usa bash. No Windows ele só roda pelo Git Bash. É uma ferramenta de
  desenvolvimento e não vai no `.exe`.

## Arquivos da Etapa B
**Novos**
- `scripts/network/network_manager.gd` (autoload `Net`)
- `scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd`
- `config/network.cfg` (endereço do relay e campo do token, **vazio**)
- `addons/nodetunnel/` (extensão NodeTunnel 1.1.1 beta, MIT, **sem** o plugin de atualização automática)
- `tools/tests/net_test.gd`, `tools/tests/net_test_bridge.gd`, `tools/tests/run_net_test.sh`
- `docs/TUTORIAL_MULTIPLAYER.md`
- `_backups/EtapaA_arquivos_substituidos.zip` (versões anteriores dos arquivos alterados)

**Modificados**
- `project.godot`: cena inicial = menu, versão 0.2.0, autoload `Net`
- `export_presets.cfg`: inclui `config/*` no jogo exportado
- `scripts/player/player.gd`: jogador remoto (fotos e interpolação), envio do estado, corpo visível, `is_grounded()`
- `scripts/player/player_look.gd` e `footsteps.gd`: usam `is_grounded()`, que também vale para remotos
- `scenes/player/player.tscn`: corpo (cápsula, visor, nome)
- `scripts/interaction/interactable.gd`: `get_net_params`, `interact_networked`, `apply_net_state`, `is_on_cooldown`
- `scripts/interaction/interactor.gd`: a interação passa pelo `Net`
- `scripts/interaction/door.gd`: sentido decidido pelo host; bloqueio decidido só pelo host; correção de estado
- `scripts/main/main.gd`: cria um jogador por participante, espera todos e remove quem sai
- `scripts/systems/game_manager.gd`: menu online sem pausar, "voltar ao menu", sair avisando os outros
- `scripts/systems/game_settings.gd`: nome do jogador
- `scripts/ui/pause_menu.gd`, `scenes/ui/pause_menu.tscn`: botão Menu principal / Sair da partida; modo "só opções" para o menu principal
- `scenes/environment/facility_level.tscn`, `tools/build_scenes.gd`: 6 pontos de nascimento
- docs: `README.md`, `ARQUITETURA.md`, `COMO_ADICIONAR_INTERATIVOS.md`, `ASSETS_E_LICENCAS.md`, `TUTORIAL_INICIANTE.md`, `VALIDACAO.md`

## Próxima etapa (C — mapa completo)
Começo depois que você fizer o roteiro de dois PCs (`TUTORIAL_MULTIPLAYER.md`, seção 5) e me contar o resultado.
Se aparecer algum problema de conexão, corrijo antes de seguir.

---

# Histórico

## Etapa A — o que foi feito
- **Passos:** 43 gravações reais (CC0 / CC BY 4.0), em 3 superfícies:
  - concreto: 7 de caminhada e 10 de corrida;
  - metal: 5 de caminhada e 7 de corrida;
  - poça: 6 de caminhada e 6 de corrida.
- A superfície vem do chão real: a chapa da sala técnica toca metal, e a nova poça sob a infiltração do corredor toca molhado.
- Caminhada e corrida usam conjuntos diferentes. O ritmo segue a distância percorrida, e o volume segue a velocidade.
- Não há passos parado nem no ar. As duas últimas variações nunca se repetem.
- **Porta:** 17 gravações reais (trinco, rangido de abertura, rangido de fechamento, batente, batida, trancada). O som acompanha os eventos reais da animação. A batida só toca quando a porta fecha de fato.
- **Áudio:**
  - novos barramentos Criatura e Interface, com controles no menu Opções;
  - cliques e "hover" nos botões do menu de pausa;
  - pastas organizadas: `footsteps`, `doors`, `ambience`, `creature`, `interactions`, `ui`.
- **Ferramenta reproduzível:** `tools/generators/process_recordings.py` baixa as fontes e refaz todo o processamento.

## Testes realizados (de verdade)
| Teste | Versão | Resultado |
|---|---|---|
| `tools/tests/smoke_test.gd` (Etapa 1, regressão) | Godot 4.6.3 | 70/70 OK |
| `tools/tests/audio_test.gd` (Etapa A) | Godot 4.6.3 | 27/27 OK |
| os dois testes acima | Godot 4.7.2 | 70/70 e 27/27 OK |
| Licença de cada gravação | conferida na página original (Freesound/Kenney) | ok |
| Volume entre variações | medido (pico de energia em janelas de 30 ms) | dentro de ±1 dB por conjunto |

**O que NÃO foi testado:** não tenho alto-falante aqui. Medi forma de onda, volume e tempo de
ataque, mas "soar bem" depende de você ouvir. Para isso há uma prévia antes/depois
(`demo_sons_antes_depois.wav`) e o roteiro abaixo.

## Problemas conhecidos
- **Arquivos antigos:** a pasta antiga `assets/audio/sfx/` (sons sintéticos da Etapa 1) ainda existe no seu
  computador. Ela não é mais usada; apague-a pelo editor (veja o tutorial).
- **Rangido da porta:** os rangidos vêm de gravações de dobradiça (Kenney) afinadas para baixo, porque não
  encontrei uma gravação livre de dobradiça de porta industrial pesada nas fontes acessíveis. Se quiser
  trocar, procure no Freesound por "heavy metal door creak" com licença CC0 e substitua `doors/creak_*.ogg`.
- **Corrida em poça:** usa as mesmas gravações de respingo da caminhada, com uma passada de bota real por
  baixo. Não há uma gravação dedicada de corrida na água.
- **Ambiente, lanterna e disjuntor:** continuam com os sons sintetizados da Etapa 1 (fora do escopo da Etapa A;
  previstos para a Etapa I).
- **Aviso ao fechar o modo headless:** "leaked instances" aparece só nos testes automáticos sem placa de som.
  É comportamento do motor, já documentado.

## Arquivos criados ou modificados na Etapa A
**Novos**
- `assets/audio/footsteps/**` (43 `.ogg`), `assets/audio/doors/*` (17 `.ogg`), `assets/audio/ui/*` (2 `.ogg`)
- `assets/audio/interactions/*.wav` (lanterna e disjuntor movidos de `sfx/`)
- `assets/audio/CREDITOS_AUDIO.md`, `assets/audio/creature/LEIA-ME.txt`
- `assets/textures/decal_puddle_albedo.png`, `decal_puddle_orm.png`
- `scripts/interaction/door_audio.gd`, `scripts/environment/surface_zone.gd`
- `tools/generators/process_recordings.py`, `tools/tests/audio_test.gd`
- `docs/PROGRESSO.md`
- `_backups/PanicoNoServidor_Etapa1.zip` (cópia da Etapa 1; a pasta tem `.gdignore`, então o Godot a ignora)

**Modificados**
- `scripts/player/footsteps.gd`: superfícies, caminhada/corrida, sinal `step_played`
- `scripts/interaction/door.gd`: eventos de movimento para o som; a lógica de física não mudou
- `scripts/systems/audio_library.gd`: catálogo novo
- `scripts/systems/game_settings.gd`: volumes de Criatura e Interface
- `scripts/ui/pause_menu.gd` e `scenes/ui/pause_menu.tscn`: novos sliders e sons de interface
- `default_bus_layout.tres`: barramentos Creature e UI
- `project.godot`: camada de física 4 "surface_zone"
- `tools/build_scenes.gd`, `scenes/interactables/industrial_door.tscn`, `scenes/environment/facility_level.tscn`: som da porta, piso metálico marcado, poça
- `tools/generators/make_audio.py` (não gera mais passos/porta), `make_textures.py` (poça)
- `tools/tests/smoke_test.gd`: referência de som atualizada
- docs: `ARQUITETURA.md`, `ASSETS_E_LICENCAS.md`, `TUTORIAL_INICIANTE.md`, `VALIDACAO.md`
