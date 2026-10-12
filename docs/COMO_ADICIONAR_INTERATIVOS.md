# Como adicionar novos objetos interativos

O jogador NÃO precisa ser modificado. Ele só procura nós do tipo `Interactable`.

## Regras do contrato
1. O objeto precisa de um nó **`Area3D` com o script `interactable.gd`** (ou um script que herde dele).
2. Essa área precisa de um **`CollisionShape3D`** cobrindo a parte "clicável".
3. A área fica na **camada de física 3** (o script já configura isso sozinho).
4. A mensagem exibida é `Pressione [E] para <prompt_text>`.

## Jeito 1: pelo editor, sem programar a área (usando o sinal)
Exemplo: um botão que liga um alarme.
1. Monte o visual do botão (MeshInstance3D etc.) dentro de um `Node3D` chamado `AlarmButton`.
2. Adicione um filho `Area3D`, renomeie para `InteractArea` e, no Inspector, em *Script*,
   carregue `res://scripts/interaction/interactable.gd`.
3. Dentro da `InteractArea`, adicione um `CollisionShape3D` com uma `BoxShape3D` do tamanho do botão.
4. No Inspector da `InteractArea`, preencha **Prompt Text** = `apertar o botão`.
5. Crie um script no `AlarmButton`:

```gdscript
extends Node3D

func _ready() -> void:
	$InteractArea.interacted.connect(_on_interacted)

func _on_interacted(interactor: Node) -> void:
	print("Alarme acionado!")
	# Mensagem curta na tela:
	if interactor.has_method(&"show_feedback"):
		interactor.show_feedback("O alarme não responde...")
```

## Jeito 2: por herança (para objetos reutilizáveis)
Veja `scripts/interaction/breaker_switch.gd` e `inspectable.gd`. Modelo:

```gdscript
class_name Valve
extends Interactable

var is_open := false

func get_prompt() -> String:
	return "fechar a válvula" if is_open else "abrir a válvula"

func can_interact(interactor: Node) -> bool:
	return super.can_interact(interactor)  # adicione condições extras aqui

func _on_interact(interactor: Node) -> void:
	is_open = not is_open
	prompt_changed.emit()   # avisa o jogador que o texto mudou
```

## Dicas
- Para desativar temporariamente: `enabled = false` (a mensagem some sozinha).
- Para mudar o texto em tempo real, altere `prompt_text` (o sinal `prompt_changed` é emitido automaticamente).
- Se o objeto for removido (`queue_free`) enquanto está na mira, o Interactor limpa o alvo sozinho.
- A área pode ser um pouco **maior** que o objeto visual para facilitar a mira. Ela não bloqueia a passagem.
- Sons: use `AudioLibrary.load_stream(caminho)` + `AudioLibrary.play_on(player, stream)`. Se o
  arquivo não existir, nada acontece (sem erro).

## Reutilizando a porta
Arraste `scenes/interactables/industrial_door.tscn` para a cena. Ela cabe num vão de
**1,70 m × 2,55 m** numa parede de 0,30 m. No Inspector:
- `Open Angle Deg`: ângulo de abertura;
- `Open Duration`: tempo para abrir/fechar;
- `Open Away From Player`: abre para longe de quem interage (os dois lados);
- `Locked` + `Locked Message`: porta trancada;
- `Prompt Open/Close/Locked`: textos.


## E no multiplayer?
Nada muda para objetos simples. Quando alguém aperta **E**, o pedido vai para o host. O host confere
a distância, os pedidos repetidos e a recarga, e depois manda **todos os computadores** executarem
`_on_interact` do seu objeto, na mesma ordem.

Regras para não dar diferença entre os jogadores:
1. Em `_on_interact`, **não use números aleatórios** nem a hora do relógio para decidir o resultado.
   Se precisar, peça ao host:
   ```gdscript
   func get_net_params(interactor: Node) -> Dictionary:   # roda só no host
       return {"sorteio": randi() % 3}

   func _on_interact(interactor: Node) -> void:            # roda em todos
       var resultado: int = last_net_params.get("sorteio", randi() % 3)
   ```
2. Mensagens de retorno (`interactor.show_feedback(...)`) aparecem só para quem interagiu. Isso é automático.
3. Se o objeto tiver um estado que muda sozinho com o tempo, o host pode corrigir todos com
   `Net.broadcast_object_state(self, {...})`, e o objeto aplica em `apply_net_state(estado)`.
   Veja `door.gd` como exemplo.
