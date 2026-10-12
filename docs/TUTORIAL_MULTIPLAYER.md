# Tutorial do multiplayer — Pânico no Servidor (Etapa B)

O jogo agora abre num **menu principal**. Dele você pode:
- **Jogar sozinho**, como antes;
- abrir o **Multiplayer** e criar ou entrar numa sala de **2 a 6 jogadores**:
  - pela **rede local** (mesmo Wi-Fi ou cabo);
  - ou pela **internet**, sem abrir portas no roteador e sem VPN.

Neste modo, quem cria a sala é o **host**. O computador do host precisa ficar ligado durante toda a partida.
Se o host sair, a partida acaba para todos e cada um volta ao menu com um aviso.

---

## 1. Testar no seu próprio PC (duas janelas)

Este é o teste mais rápido e não precisa de outro computador.

1. Abra o projeto no Godot 4.6.3.
2. No menu **Depurar** (*Debug*), escolha **Personalizar instâncias de execução...** (*Customize Run Instances...*).
3. Marque **Ativar múltiplas instâncias** (*Enable Multiple Instances*). Em **Instâncias**, coloque **2** e clique em OK.
4. Aperte **F5**. Abrem duas janelas do jogo.
5. **Janela 1:** clique em **Multiplayer**, digite um nome e clique em **Criar sala na rede local**.
6. **Janela 2:** clique em **Multiplayer**, digite outro nome, escreva `127.0.0.1` no campo de IP e clique em **Entrar**.
7. Os dois nomes aparecem na lista da sala, e o host aparece com ★.
8. Na janela 1, clique em **Iniciar partida**.
9. Teste, alternando o foco entre as duas janelas:
   - andar;
   - ligar a lanterna (F);
   - abrir e fechar a porta da manutenção (E);
   - ligar o disjuntor do depósito;
   - abrir o menu com Esc (o jogo **não** pausa numa partida online);
   - **Sair da partida**.

> Esse teste prova que o jogo funciona, mas **não** prova a conexão entre dois computadores.
> Os passos 2 e 3 abaixo fazem esse teste.

Depois, volte o número de instâncias para 1 para rodar o jogo normalmente.

---

## 2. Rede local com dois computadores (mesma casa)

1. Os dois PCs precisam ter **a mesma versão do jogo**. Se for diferente, o host recusa e avisa.
2. **No PC do host:**
   - Multiplayer → **Criar sala na rede local**;
   - a tela mostra um **Endereço**, por exemplo `192.168.0.15:24565`;
   - se aparecerem outros endereços na dica, guarde-os também.
3. **No outro PC:**
   - Multiplayer → digite o endereço no campo de IP (pode digitar só `192.168.0.15`) → **Entrar**.
4. **Firewall do Windows:** na primeira vez que o host criar a sala, o Windows pode perguntar se permite
   o acesso. Marque **Redes privadas** e clique em **Permitir**. Se a janela não apareceu e ninguém consegue entrar:
   1. Abra **Iniciar → "Firewall do Windows Defender" → "Permitir um aplicativo pelo firewall"**.
   2. Clique em **Alterar configurações** e depois em **Permitir outro aplicativo...**.
   3. Selecione o executável do jogo (ou o `Godot_v4.6.3-stable_win64.exe`, se estiver testando pelo editor).
   4. Marque **Privada** e clique em OK.
5. O Wi-Fi do host precisa estar como **rede privada**. Para conferir:
   - abra **Configurações → Rede e Internet → (sua rede)**;
   - em **Tipo de perfil de rede**, escolha **Privada**.

A porta usada é **24565 (UDP)**. Ela só importa dentro da sua casa. **Não** é preciso mexer no roteador.

---

## 3. Pela internet (amigos em outras casas)

O jogo usa o **NodeTunnel**, um "relay" gratuito: os jogadores se conectam a um servidor público, que repassa as mensagens. Assim ninguém precisa abrir portas nem usar VPN.

### 3.1 Obter o token do aplicativo (grátis, uma vez só)
O relay público pede um **token de aplicativo** (ele identifica o seu jogo).
**Não é uma senha nem uma chave secreta:** ele vai junto com o jogo para os seus amigos, e isso é esperado.

1. Acesse **https://www.nodetunnel.io** e clique em **Sign Up** para criar uma conta.
2. Entre na conta. No painel (*dashboard*), cadastre o jogo com nome e descrição.
3. Copie o **token de 15 caracteres** que aparece.

Eu **não** criei conta nem token por você. Não invento credenciais, por isso o campo vem vazio.

### 3.2 Colocar o token no jogo
1. No Windows Explorer, abra a pasta do projeto e depois a pasta `config`.
2. Abra `network.cfg` com o **Bloco de Notas**.
3. Na linha `app_id=""`, cole o token entre as aspas. Exemplo: `app_id="AbCdEfGhIjKlMnO"`.
4. Salve. Feche e abra o jogo de novo.

Na tela Multiplayer, o aviso laranja some e os botões da parte "Pela internet" ficam ativos.

### 3.3 Jogar
1. **Host:** Multiplayer → **Criar sala online**. Aparece um **código** curto, por exemplo `E4XZN`.
   Use **Copiar** e mande o código para os amigos (WhatsApp, Discord...).
2. **Amigos:** Multiplayer → cole o código → **Entrar**.
3. Quando todos aparecerem na lista, o host clica em **Iniciar partida**.

O código só vale enquanto o host estiver na sala.
Ninguém entra depois que a partida começou: o host cria uma sala nova e todos entram de novo.

### 3.4 Servidor (região)
O padrão é `us-east.nodetunnel.io:8080` (leste dos EUA), o mais próximo do Brasil entre os públicos.
- O endereço fica na linha `address=` do `network.cfg`.
- A documentação do NodeTunnel também cita `eu_central.nodetunnel.io:8080` (Europa) e escreve o servidor dos EUA como `us_east...`, com sublinhado.
- Daqui não consegui testar qual grafia responde. Se aparecer "Tempo esgotado ao conectar", troque o hífen pelo sublinhado (ou o contrário) e tente de novo.
- **Todos os jogadores precisam usar o mesmo servidor.**

---

## 4. Exportar e mandar o jogo para os amigos

1. Exporte como antes (Projeto → Exportar → *Windows Desktop* → **Exportar projeto**).
2. Na pasta de destino aparecem **dois arquivos**, e os dois são necessários:
   - `PanicoNoServidor.exe`;
   - `nodetunnel.dll`: a parte da internet; sem ela, só a rede local funciona.
3. Compacte a pasta inteira num `.zip` e envie.
4. **Token já incluído:** o token do `network.cfg` vai dentro do `.exe`. Os amigos não precisam configurar nada.
5. **Trocar o token sem exportar de novo:** coloque um arquivo `network.cfg` (no mesmo formato) **ao lado do `.exe`**. Ele tem prioridade.
6. **Versões iguais:** sempre que você mudar o jogo, mande a versão nova para todos.

O Windows SmartScreen pode avisar que o aplicativo é desconhecido, porque ele não é assinado digitalmente.
Para abrir, clique em **Mais informações → Executar assim mesmo**.

---

## 5. Roteiro de validação entre dois PCs (por favor, faça e me conte)

Faça primeiro na **rede local** e depois **pela internet**:

| # | Teste | O que deve acontecer |
|---|---|---|
| 1 | Cliente entra na sala | os dois nomes aparecem na lista; o host tem ★ |
| 2 | Host inicia | os dois entram na fase, cada um num ponto diferente |
| 3 | Andar e correr | o outro jogador se move suave, sem "teletransportes" |
| 4 | Lanterna | a lanterna do outro aparece acesa ou apagada |
| 5 | Porta da manutenção | abre e fecha igual nos dois PCs, para longe de quem abriu |
| 6 | Ficar no caminho da porta | a porta não fecha em cima de ninguém; volta a abrir |
| 7 | Disjuntor do depósito | as luzes acendem nos dois PCs |
| 8 | Portão do Setor C | a mensagem "travado" aparece só para quem tentou |
| 9 | Esc durante a partida | o menu abre, mas o jogo continua para o outro |
| 10 | Cliente sai | o host vê o aviso "... saiu da partida" e continua jogando |
| 11 | Host sai | o cliente volta ao menu com o aviso "O host encerrou a partida" |
| 12 | Desligar o Wi-Fi de alguém | em até ~10 s ele volta ao menu com um aviso |

Mande-me também: a **cidade/região** de cada um, se houve **atraso perceptível** e qualquer mensagem de erro.

---

## 6. Problemas comuns

| Mensagem ou sintoma | O que fazer |
|---|---|
| "Falta o App ID do NodeTunnel..." | faça o passo 3.1 e o 3.2 |
| "O relay não aceitou o App ID" | o token foi copiado errado; confira letras maiúsculas e minúsculas |
| "Sala não encontrada" | código digitado errado, ou o host saiu da sala |
| "O host recusou a entrada" | a sala está cheia (6), a partida já começou ou as versões do jogo são diferentes |
| "Tempo esgotado ao conectar" | **LAN:** IP errado, PCs em redes diferentes ou Firewall do Windows (passo 2.4). **Internet:** sem internet, ou o servidor de relay está fora do ar ou com outra grafia (passo 3.4) |
| "Versão diferente" | mande o jogo atualizado para todos |
| "Sem resposta do host há 10 segundos" | a internet do host caiu ou o jogo dele travou/fechou |
| "Plugin NodeTunnel não encontrado" | a pasta `addons/nodetunnel` sumiu do projeto, ou o `nodetunnel.dll` não está ao lado do `.exe` |

---

## 7. Limitações conhecidas (sem esconder nada)

- **NodeTunnel ainda está em beta.**
  - A própria documentação diz que os servidores públicos não são garantidos até a versão final, e que a compatibilidade pode mudar.
  - Se o relay público parar ou mudar de versão, a parte da internet para de funcionar até atualizarmos o plugin. A rede local continua funcionando.
- **Limites do relay público:**
  - as sessões duram no máximo 4 horas;
  - há limite de tráfego por jogador (64 KB/s). Medi o tráfego numa sala de 6 jogadores na rede local
    (6 instâncias neste ambiente de testes; não foi pelo relay público):
    - cada convidado recebe cerca de 5 KB/s e envia cerca de 1 KB/s;
    - o host envia cerca de 25 KB/s, porque repassa a posição de todos para todos.
  - Pelo relay há um pouco mais, por causa dos cabeçalhos. Mesmo assim fica bem abaixo do limite e de qualquer internet doméstica.
- **Pela internet, o host não consegue "expulsar" um jogador** (o plugin ainda não permite).
  - O jogo recusa entradas inválidas antes da conexão: sala cheia, partida em andamento ou versão diferente.
  - Na rede local, a expulsão funciona.
- **Sem troca de host:** se o host sair, a partida termina. Foi assim que você pediu.
- **Sem entrar no meio da partida:** é preciso voltar ao menu e criar a sala de novo.
- **O corpo dos outros jogadores é provisório:** uma cápsula colorida com visor e o nome em cima. Os modelos de verdade ficam para a etapa de polimento.
- **Cada jogador controla o próprio movimento,** e o host confere se é plausível:
  - velocidade impossível ou "teletransporte" faz o jogador voltar à última posição válida;
  - interações de longe são recusadas.
  - Não é um anti-trapaça completo, mas evita os abusos simples.
