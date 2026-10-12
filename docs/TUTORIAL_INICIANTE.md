# Tutorial para iniciantes — Pânico no Servidor (Etapa 1)

Siga na ordem. Nada aqui exige programação.

---

## 1. Qual versão do Godot baixar e de onde
- Versão: **Godot 4.6.3-stable, edição padrão ("Standard")**. **Não** baixe a versão ".NET"
  (ela é para C#, e este projeto usa GDScript).
- Página oficial: <https://godotengine.org/download/archive/4.6.3-stable/>
  → em **Windows**, clique em **Standard** (arquivo `Godot_v4.6.3-stable_win64.exe.zip`).
- Espelho oficial no GitHub: <https://github.com/godotengine/godot/releases/tag/4.6.3-stable>
- O projeto também foi testado no **4.7.2**. Se você abrir num Godot mais novo, ele pode pedir
  para "converter/atualizar" o projeto. Faça um backup antes (passo 11).

## 2. Preciso instalar mais alguma coisa?
**Não.** O Godot é um único executável, sem instalador. Só será preciso baixar algo extra na hora de
gerar o `.exe` (os *modelos de exportação*, passo 12), e isso é feito dentro do próprio Godot.
Mantenha o driver da NVIDIA atualizado.

Dica: extraia o Godot em `C:\Godot\` e crie um atalho na Área de Trabalho para
`Godot_v4.6.3-stable_win64.exe`. O arquivo `..._console.exe` é igual, mas abre também uma janela
de console com mensagens técnicas, o que é útil para depuração.

## 3. Estrutura de pastas
| Pasta | Para que serve |
|---|---|
| `scenes/` | cenas do jogo (`.tscn`): fase, jogador, porta, interface |
| `scripts/` | código GDScript (`.gd`), separado por assunto |
| `assets/` | texturas, materiais, sons, fonte, ambiente visual |
| `docs/` | esta documentação |
| `tools/` | ferramentas de desenvolvimento e testes (não vão para o `.exe`) |
| `.godot/` | **cache criado automaticamente** pelo Godot na primeira abertura. Pode ser apagado com o Godot fechado; ele é recriado. |

Os arquivos `.import` e `.uid` ao lado das texturas, sons e scripts são do Godot. Não apague.

## 4. Como obter os arquivos
Os arquivos já estão na pasta `PÂNICO NO SERVIDOR` da sua Área de Trabalho. Também foi enviado
um `.zip` com o mesmo conteúdo, como cópia de segurança.

## 5. Importar o projeto no Godot
1. Abra o Godot. Aparece o **Gerenciador de Projetos**.
2. Clique em **Importar** (*Import*).
3. Navegue até `Área de Trabalho\PÂNICO NO SERVIDOR` e selecione o arquivo **`project.godot`**.
4. Clique em **Importar e Editar** (*Import & Edit*).
5. Na primeira abertura, o Godot importa texturas e sons. Pode levar de 30 segundos a alguns
   minutos. Aguarde a barra de progresso terminar.

## 6. Configurar o editor (opcional)
- Idioma do editor: **Editor → Configurações do Editor → Interface → Editor → Idioma do Editor**
  → *Português (Brasil)*. O editor reinicia.
- Nada mais é obrigatório: controles, cena principal, áudio e exportação já estão configurados.

## 7. Executar pela primeira vez
- Aperte **F5**, ou clique no botão **▶ (Executar Projeto)** no canto superior direito do editor.
- O jogo abre numa janela de 1600×900, com fade a partir do preto.
- **F6** roda apenas a cena aberta no momento. Para jogar, use **F5**.
- Para fechar: Esc → **SAIR DO JOGO**, ou **F8** no editor.

## 8. Qual botão inicia a cena principal?
O **▶ Executar Projeto (F5)** sempre inicia `scenes/main/main.tscn`, que já está definida
como cena principal em *Projeto → Configurações do Projeto → Aplicação → Executar → Cena Principal*.

## 9. Roteiro de teste manual
Faça na ordem e marque o que funcionou:
1. **Mouse e câmera:** mova o mouse. Olhe totalmente para cima e para baixo; a câmera deve parar e nunca virar de ponta-cabeça.
2. **Movimento:** W/A/S/D. Ande na diagonal (W+D); a velocidade deve ser igual à de andar reto.
3. **Correr:** segure Shift + W. A câmera "abre" levemente e os passos ficam mais rápidos.
4. **Pular:** Espaço.
5. **Colisões:** ande contra paredes, pilares, tambores e caixas. Nada deve ser atravessado.
6. **Lanterna:** F liga e desliga (com clique). O ícone no canto inferior esquerdo muda para LIGADA/DESLIGADA.
7. **Zona escura:** no meio do corredor há uma lâmpada queimada. Atravesse-a com a lanterna.
8. **Porta do escritório (esquerda):** mire nela. Aparece "Pressione [E] para abrir". Aperte E.
   Ela abre para longe de você. Entre, vire-se, mire e feche por dentro. Abra de novo por dentro:
   agora ela abre para o corredor.
9. **Mensagem some:** com a mensagem na tela, olhe para outro lado; ela deve sumir.
10. **Porta fechada bloqueia:** feche a porta e tente atravessar correndo.
11. **Não esmagar:** fique parado no caminho da porta enquanto ela fecha. Ela deve parar e reabrir.
12. **Depósito (direita):** entre com a lanterna. Ao lado da porta, por dentro, há um **disjuntor vermelho**.
    Aperte E: as luzes acendem e aparece "Energia restabelecida".
13. **Através da parede:** do corredor, encoste na parede onde o disjuntor está do outro lado. Não pode aparecer mensagem.
14. **Portão do Setor C** (fim do corredor): aperte E. Aparece a mensagem de portão travado.
15. **Pausa:** Esc. O jogo congela, o mouse aparece e você não consegue andar. **CONTINUAR** volta ao normal.
16. **Opções:** Esc → OPÇÕES. Mude sensibilidade, volumes, qualidade (Baixa/Média/Alta) e tela cheia.
    Esc dentro das opções volta para o menu.
17. **Reiniciar:** Esc → REINICIAR. A cena recomeça.
18. **Resoluções:** marque/desmarque Tela cheia e redimensione a janela. A interface deve continuar legível.
19. **Alt+Tab:** ao sair da janela, o jogo pausa sozinho.

## 10. Interpretar e corrigir erros (painel Depurador)
- Com o jogo rodando pelo editor, veja o painel inferior:
  - **Saída** (*Output*): mensagens gerais.
  - **Depurador → Erros** (*Debugger → Errors*): erros (vermelho) e avisos (amarelo).
- **Erro vermelho** com caminho `res://scripts/...gd:123`: clique duas vezes na linha e o editor
  abre o script exatamente na linha do problema.
- **Aviso amarelo** geralmente não impede o jogo, mas vale anotar.
- Problemas comuns:
  - *"Cannot open file"* ou *"Failed loading resource"*: um arquivo foi movido ou renomeado
    fora do Godot. **Sempre mova e renomeie arquivos pelo painel Sistema de Arquivos do Godot**, que atualiza as referências.
  - Tela preta / erro de Vulkan ou D3D12: atualize o driver da NVIDIA. Como alternativa, em
    *Projeto → Configurações do Projeto → Renderização → Dispositivo de Renderização*, troque o *Driver* (Windows).
  - Texturas rosa/quebradas: feche o Godot, apague a pasta `.godot` e abra de novo (reimporta tudo).
- Ao me pedir ajuda, copie o texto do erro (clique com o botão direito → *Copiar Erro*) e me envie.

## 11. Cópia de segurança antes das próximas etapas
Forma simples:
1. Feche o Godot.
2. Clique com o botão direito na pasta `PÂNICO NO SERVIDOR` → **Enviar para → Pasta compactada (zip)**.
3. Renomeie, por exemplo, para `PanicoNoServidor_etapa1_2026-10-11.zip` e guarde em outro lugar (pendrive, nuvem).
4. A pasta `.godot` pode ser excluída do zip; ela é recriada.

Forma recomendada (opcional): usar **Git** (o arquivo `.gitignore` já está pronto) com um repositório privado no GitHub.

## 12. Exportar para Windows (.exe)
**a) Instalar os modelos de exportação (só uma vez, cerca de 1,2 GB):**
1. **Editor → Gerenciar Modelos de Exportação** (*Manage Export Templates*).
2. Clique em **Baixar e Instalar** (*Download and Install*) e aguarde.
   - Sem internet no Godot? Baixe `Godot_v4.6.3-stable_export_templates.tpz` na página do passo 1
     (*Export templates → Standard*) e use **Instalar do Arquivo**.

**b) Exportar:**
1. **Projeto → Exportar** (*Project → Export*).
2. A predefinição **Windows Desktop** já existe. Selecione-a.
3. Clique em **Exportar Projeto**, escolha uma pasta (ex.: `build/windows/`) e o nome `PanicoNoServidor.exe`.
4. **Desmarque "Exportar com Depuração"** para a versão final (marcada, o jogo abre também um console).
5. Clique em **Salvar**. O `.pck` já vai embutido no `.exe` (opção *Embed PCK* ligada), então o jogo é **um único arquivo**.

## 13. Compartilhar o executável
1. Compacte o `.exe` num `.zip` e envie (Google Drive, Discord etc.).
2. Requisitos de quem for jogar: Windows 10/11 64 bits, placa de vídeo com Vulkan ou Direct3D 12 e drivers atualizados.
3. O Windows pode mostrar **"O Windows protegeu o computador"** (SmartScreen), porque o `.exe` não
   tem assinatura digital. A pessoa clica em **Mais informações → Executar assim mesmo**. Isso é normal para jogos independentes.
4. As configurações do jogador ficam em `%APPDATA%\Godot\app_userdata\Pânico no Servidor\settings.cfg`.

## 14. Limitações desta etapa
- Só um jogador. Não há multiplayer, monstros, inventário, objetivos nem fuga (por definição da etapa).
- Não há menu principal: o jogo começa direto na fase.
- Só teclado e mouse (o InputMap aceita adicionar controle depois).
- Sem stamina, agachamento ou animações de corpo.
- Iluminação totalmente dinâmica, sem GI pré-calculada: alguns cantos ficam pretos (de propósito,
  mas pode precisar de ajuste fino).
- Na qualidade **Baixa** as luminárias ficam sem sombra, e um pouco de luz pode "vazar" por paredes finas.
- Os sons e as texturas são procedurais, gerados para o protótipo. Funcionam, mas podem ser
  trocados por gravações reais (veja `ASSETS_E_LICENCAS.md`).
- O cenário é modular, feito de blocos e cilindros. Não há modelos 3D detalhados ainda.
- O FPS no seu PC **não foi medido**. Veja `ARQUITETURA.md → Desempenho`.

## 15. Como a arquitetura recebe multiplayer e monstros
Resumo (detalhes em `ARQUITETURA.md`):
- O jogador já separa **entrada** (`_gather_input`) de **física**. Na rede, a entrada vem de outro computador.
- `is_local` desliga câmera, mouse e teclas de jogadores remotos.
- `spawn_player()` já cria jogadores por índice em pontos de nascimento.
- Interações recebem **quem** interagiu. O estado da porta é um único número, fácil de sincronizar.
- Luzes têm `set_powered()` (geradores/fusíveis), a lanterna tem `has_power()` (bateria), há
  camadas de física documentadas e uma rede de segurança contra queda.

---

# ETAPA A — Como testar os novos sons (passos e porta)

### Antes de tudo: limpar os sons antigos
1. Abra o projeto no Godot.
2. No painel **Arquivos** (canto inferior esquerdo), abra `assets/audio/`.
3. Se existir a pasta **`sfx`**, clique nela com o botão direito → **Excluir** (*Delete*) → confirme.
   Ela tem os sons sintéticos da Etapa 1, que não são mais usados.
4. Aguarde a reimportação dos sons novos (barra no canto superior direito).

### Roteiro de audição (use fone de ouvido)
1. **F5** para jogar.
2. **Passos no concreto:** ande pelo corredor. Os passos devem soar como sapato em piso duro, sem
   a mesma batida repetida em sequência.
3. **Correr:** segure **Shift**. As passadas ficam mais rápidas, mais secas e mais fortes, com sons
   diferentes da caminhada.
4. **Parar:** solte as teclas. Os passos param na hora, sem "passo fantasma".
5. **Pular:** aperte **Espaço** andando. Nenhum passo no ar; um passo mais forte ao aterrissar.
6. **Poça:** logo depois da zona escura (lâmpada queimada), junto à parede esquerda, embaixo da mancha de infiltração, há uma poça escura e
   brilhante. Pise nela: os passos viram respingos.
7. **Metal:** entre no **Depósito B** (porta da direita), vá até o canto do transformador (piso de
   chapa xadrez). Os passos viram passos em metal.
8. **Porta (abrir):** mire na porta do escritório e aperte **E**. Ordem esperada: *clac* do trinco →
   rangido grave da dobradiça enquanto ela abre → batida surda no fim.
9. **Porta (fechar):** aperte **E** de novo. Rangido durante o movimento → **batida pesada só quando a
   porta encosta no batente**.
10. **Inverter:** aperte E enquanto ela ainda está se movendo. O rangido troca de sentido sem cortes bruscos.
11. **Distância:** abra a porta e se afaste. O som fica mais baixo e mais abafado e vem da direção certa.
12. **Volumes:** **Esc → OPÇÕES** → mexa em **Efeitos sonoros** (passos e porta), **Som ambiente**,
    **Criatura** (sem sons ainda) e **Interface** (cliques do menu).

Se algum som estiver alto, baixo ou estranho, diga qual (ex.: "corrida no concreto está estalando") e
eu ajusto. Os volumes ficam nos campos `walk_volume_db`/`sprint_volume_db` do nó `Footsteps` (cena
`scenes/player/player.tscn`) e nos campos do nó `DoorSounds` da porta.

### Rodar os testes automáticos (opcional)
No Prompt de Comando, dentro da pasta do projeto:
```
"C:\Godot\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script res://tools/tests/audio_test.gd
"C:\Godot\Godot_v4.6.3-stable_win64_console.exe" --headless --path . --script res://tools/tests/smoke_test.gd
```
Resultados esperados: `RESULTADO ÁUDIO: 27 OK, 0 FALHA(S)` e `RESULTADO: 70 OK, 0 FALHA(S)`.

---

# ETAPA B — O jogo agora começa no menu principal

- **F5** agora abre o **menu principal** (`scenes/ui/main_menu.tscn`), e não mais a fase direto.
- Clique em **Jogar sozinho** para jogar como antes.
- Para testar só a fase pelo editor, abra `scenes/main/main.tscn` e aperte **F6** (*Executar cena atual*).
- O seu nome de jogador fica salvo junto com as opções.
- Tudo sobre jogar com amigos está em **`docs/TUTORIAL_MULTIPLAYER.md`**.
