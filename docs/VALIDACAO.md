# Validação — Etapa 1

Legenda:
- **AUTO**: verificado automaticamente, executando o Godot real (modo *headless*, sem janela) com o
  teste `tools/tests/smoke_test.gd`, que simula teclas e mede o resultado.
- **IMAGEM**: verificado olhando quadros renderizados de verdade (Forward+ via Vulkan por software, 1280×720).
- **MANUAL**: depende de você testar no editor (veja o roteiro no `TUTORIAL_INICIANTE.md`, passo 9).

Versões usadas nos testes: **Godot 4.6.3-stable** (principal) e **4.7.2-stable** (compatibilidade).
Resultado: **70 de 70 verificações passaram nas duas versões.**

| Item do checklist | Status | Como foi verificado |
|---|---|---|
| O projeto abre na versão escolhida | AUTO + MANUAL | importação completa no 4.6.3 sem erros; abrir a interface gráfica do editor é teste seu |
| Cena principal configurada | AUTO | `main.tscn` carrega como cena principal |
| Personagem na posição inicial | AUTO | posição (0, 0, 0,6), apoiado no chão |
| Movimentação funciona | AUTO + MANUAL | andar 3,0 m/s (2,7 m percorridos no 1º segundo, contando a aceleração), corrida 5,4 m/s, diagonal 3,0 m/s (normalizada), pulo, gravidade. A "sensação" é teste seu |
| Mouse controla a câmera | AUTO (lógica) + MANUAL | giro horizontal e limites verticais testados via função; o mouse físico só pode ser testado por você |
| Colisões funcionam | AUTO | não atravessa parede, portão nem porta fechada |
| Lanterna liga/desliga | AUTO + IMAGEM | tecla F simulada; HUD atualiza; feixe visível nos quadros |
| Porta abre e fecha | AUTO | abre para longe do jogador, pelos dois lados; alternância rápida termina estável; não fecha através do jogador nem o empurra |
| Mensagem de interação aparece/some | AUTO | texto correto, some ao olhar para longe e ao remover o objeto |
| Não cair para fora do mapa | AUTO | geometria fechada + rede de segurança devolve ao início |
| Menu de pausa | AUTO + IMAGEM | Esc pausa, jogador não anda nem liga a lanterna, Esc despausa, menu renderizado |
| Áudio opcional ausente não quebra | AUTO | projeto rodado **sem a pasta de áudio inteira**: zero erros |
| Interface em resoluções diferentes | IMAGEM + MANUAL | layout com âncoras e escala `canvas_items` (base 1920×1080), conferido em 1280×720; teste outras resoluções |
| Sem referências quebradas | AUTO | todas as cenas carregam; exportação do `.pck` sem erros; o `.pck` exportado roda e carrega os sons |
| Sem erros críticos de GDScript | AUTO | todos os scripts compilam e rodam nos testes sem erros |
| Projeto organizado para próximas etapas | revisão | ver `ARQUITETURA.md` |

## Observações honestas
- **Desempenho não medido.** Não há GPU no ambiente de desenvolvimento. Meça no seu PC
  (Depurador → Monitores) e me informe o FPS em Média e Alta.
- **Aviso ao fechar só em modo headless:** sem placa de som, o Godot imprime
  `ObjectDB instances leaked at exit` / `resources still in use at exit` ao sair. Reproduzi o mesmo
  aviso num projeto vazio com um único som, então é comportamento do motor sem dispositivo de áudio,
  não um defeito do jogo.
- A aparência foi conferida com renderização por software. Cores e brilho podem variar um pouco
  numa GPU real e no seu monitor. Ajustes de iluminação são esperados após o seu primeiro teste.
- O `.exe` final não foi gerado aqui, porque precisaria dos modelos de exportação (1,2 GB). O preset e o
  empacotamento foram validados.

## Rodar os testes você mesmo (opcional)
No Prompt de Comando, dentro da pasta do projeto:
```
"C:\Godot\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script res://tools/tests/smoke_test.gd
```
Ao final aparece `=== RESULTADO: 70 OK, 0 FALHA(S) ===`.

---

## Etapa A — sons de passos e porta (11/10/2026)

Teste automático `tools/tests/audio_test.gd`: **27/27 OK** no Godot 4.6.3 e no 4.7.2.
O teste de regressão da Etapa 1 continua **70/70 OK** nas duas versões.

| Critério | Status | Como foi verificado |
|---|---|---|
| Gravações reais e licenciadas | revisão | cada licença conferida na página original; lista em `assets/audio/CREDITOS_AUDIO.md` |
| Arquivos existem e carregam (43 passos, 17 porta) | AUTO | carregados pelo Godot |
| Caminhada e corrida com sons diferentes | AUTO | andando só toca `walk_*`, correndo só toca `run_*` |
| Ritmo sincronizado com a velocidade | AUTO | 7 passos em 5,7 m (esperado ~7,3) |
| Para quando o jogador para | AUTO | 1 s parado = 0 passos |
| Sem passos no ar | AUTO | todos os passos registrados com o jogador no chão |
| Variações sem repetição perceptível | AUTO | nunca repete o mesmo arquivo em seguida |
| Superfície pelo chão real | AUTO | corredor = concreto; chapa da sala técnica = metal; poça = molhado |
| Áudio 3D com atenuação configurável | AUTO + MANUAL | AudioStreamPlayer3D com `unit_size`/`max_distance` exportados; a sensação de distância é teste seu |
| Porta: trinco → rangido → batente | AUTO | ordem e tempo verificados quadro a quadro |
| Batida só ao fechar de verdade | AUTO | no meio do fechamento não há batida; no estado CLOSED, há |
| Barramentos Geral/Ambiente/Efeitos/Criatura/Interface | AUTO | existem e têm controle no menu |
| Os sons "soam bem" | **MANUAL** | não há como ouvir aqui; ouça a prévia e siga o roteiro do tutorial |

---

## Etapa B — multiplayer (12/10/2026)

Cada teste abre **processos separados do Godot** (`tools/tests/run_net_test.sh`), conectados de verdade:
- por **ENet** (LAN, 127.0.0.1);
- e pelo **servidor de relay oficial do NodeTunnel**, compilado do código-fonte e rodando localmente.

Resultado: **290/290 no Godot 4.6.3** e **213/213 no 4.7.2** (subconjunto). A regressão continua 70/70 e 27/27.

| Critério do pedido | Status | Como foi verificado |
|---|---|---|
| 2 a 6 jogadores | AUTO | 6 instâncias jogando juntas; a 7ª é recusada ("sala está cheia") |
| Host cria sala, amigos entram com código real | AUTO | código gerado pelo relay (ex.: `E4XZN`) ou IP; sala inexistente → "Sala não encontrada" |
| Menu principal, criar/entrar, lista, nome, indicador de host, iniciar | AUTO + IMAGEM | cenário `ui` aperta os botões de verdade; telas renderizadas |
| Mensagens de conexão/desconexão e falhas | AUTO | entrada/saída na sala e na partida; erros de IP, token, relay fora do ar, tempo esgotado |
| Volta ao menu | AUTO | quando o host sai, cai, ou quando o jogador sai |
| Gratuito, sem portas, sem VPN, sem segredos no jogo | revisão | NodeTunnel (MIT, relay gratuito); o token não é segredo e vem **vazio**; não criei conta nem credenciais |
| Host valida ações importantes | AUTO | teletransporte recusado e corrigido; interação de longe recusada; pedido duplicado ignorado |
| Jogadores sincronizados com interpolação | AUTO | diferença ≤ 0,004 m após parar; maior salto entre quadros 0,116 m (andando a 3 m/s) |
| Portas, itens e estados sincronizados | AUTO | porta com o mesmo ângulo nos PCs, bloqueio decidido pelo host, disjuntor/luzes, lanterna |
| Sem ações duplicadas | AUTO | dois pedidos no mesmo quadro → a porta muda uma vez só |
| Host sai → fim controlado, sem troca de host | AUTO | clientes voltam ao menu com o motivo em 0,6 s (saída normal) ou em 6–12 s (queda) |
| LAN com 2 jogadores primeiro, depois internet | AUTO (mesma máquina) + **MANUAL** | **falta o seu teste entre dois PCs** e pelo relay público com o seu token |

**Não declaro o multiplayer funcional entre computadores** até você fazer o roteiro da seção 5 de
`TUTORIAL_MULTIPLAYER.md`. Aqui tudo rodou numa única máquina, embora como processos separados e por rede real.
