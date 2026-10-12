# Pânico no Servidor — terror cooperativo (Etapas 1, A e B)

Terror em primeira pessoa numa instalação subterrânea abandonada (Setor B-2, Nível -3).
Já tem:
- movimentação completa, lanterna e sistema de interação;
- portas industriais e disjuntor;
- cenário com atmosfera de terror;
- passos e porta com gravações reais;
- HUD e menu de pausa;
- **menu principal com multiplayer cooperativo de 2 a 6 jogadores**: rede local, ou internet via relay gratuito, sem abrir portas.

| Item | Valor |
|---|---|
| Motor | **Godot 4.6.3-stable** (versão padrão, *não* a .NET) |
| Renderizador | Forward+ |
| Física | Jolt Physics (já vem no Godot) |
| Linguagem | GDScript |
| Dependências externas | NodeTunnel (já incluído em `addons/nodetunnel`, MIT), só para jogar pela internet |

## Como abrir (resumo)
1. Baixe o Godot 4.6.3 em <https://godotengine.org/download/archive/4.6.3-stable/> (Windows → *Standard*).
2. Abra o Godot → **Importar** → selecione o arquivo `project.godot` desta pasta.
3. Aguarde a primeira importação e aperte **F5** (ou o botão ▶ no canto superior direito).

O passo a passo completo para iniciantes está em **`docs/TUTORIAL_INICIANTE.md`**.

## Controles
| Tecla | Ação |
|---|---|
| W A S D (ou setas) | mover |
| Mouse | olhar |
| Shift | correr |
| Espaço | pular |
| E | interagir |
| F | lanterna |
| Esc | pausar / voltar (online abre o menu sem pausar o jogo) |

Todos os controles podem ser alterados em **Projeto → Configurações do Projeto → Mapa de Entrada**.

## O que explorar
- Corredor principal com tubulações, eletrocalha, duto de ventilação e lâmpadas falhando.
- Uma lâmpada queimada no meio do corredor: zona escura, use a lanterna.
- **Escritório de manutenção** (porta à esquerda).
- **Depósito B / sala técnica** (porta à direita): está sem luz. Procure o **disjuntor** ao lado da porta, por dentro.
- **Portão do Setor C** no fim do corredor (trancado, preparado para as próximas etapas).

## Documentação
- **`docs/TUTORIAL_MULTIPLAYER.md`: jogar com amigos (rede local e internet), token gratuito do NodeTunnel, firewall, exportação e roteiro de teste entre dois PCs.**
- `docs/PROGRESSO.md`: situação de cada etapa, testes realizados e problemas conhecidos.
- `docs/TUTORIAL_INICIANTE.md`: instalar, abrir, jogar, depurar, fazer backup, exportar `.exe`.
- `docs/ARQUITETURA.md`: estrutura, cenas, scripts, sinais e preparação para multiplayer/monstros.
- `docs/COMO_ADICIONAR_INTERATIVOS.md`: como criar novos objetos interativos.
- `docs/VALIDACAO.md`: o que foi testado automaticamente e o que você deve testar à mão.
- `docs/ASSETS_E_LICENCAS.md`: origem de texturas, sons e fonte, e alternativas gratuitas.

## Testes automáticos
```
godot --headless --path . --script res://tools/tests/smoke_test.gd
```
São 70 verificações (movimento, colisão, lanterna, porta, disjuntor, pausa etc.).
Também há `audio_test.gd` (sons) e o teste de rede `tools/tests/run_net_test.sh`
(abre várias instâncias reais do Godot; precisa de bash, por exemplo o Git Bash no Windows).
