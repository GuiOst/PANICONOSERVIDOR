@icon("res://assets/textures/ui/icon_interact.svg")
class_name Interactable
extends Area3D
## CONTRATO DE INTERAÇÃO — base de todo objeto com o qual o jogador interage.
##
## Como funciona:
##  - É uma Area3D na camada de física 3 ("interactable"). O raio de interação
##    do jogador (Interactor) enxerga essa camada E a camada do mundo (1).
##    Se uma parede estiver na frente, o raio acerta a parede primeiro, então
##    não existe interação através de paredes.
##  - Precisa de pelo menos um CollisionShape3D filho, cobrindo a parte
##    "clicável" do objeto.
##
## Duas formas de usar (ver docs/COMO_ADICIONAR_INTERATIVOS.md):
##  1) SINAL: coloque um Interactable como filho do seu objeto e conecte
##     o sinal `interacted` a uma função do objeto (é o que a Porta faz).
##  2) HERANÇA: crie um script que `extends Interactable` e sobrescreva
##     `_on_interact()`, `get_prompt()` e/ou `can_interact()`.

## Emitido quando um jogador interage. `interactor` é o nó Interactor do jogador.
signal interacted(interactor: Node)
## Emitido quando o texto exibido muda (ex.: "abrir" -> "fechar").
signal prompt_changed

const INTERACTABLE_LAYER := 3

## Verbo mostrado na tela: "Pressione [E] para <prompt_text>".
@export var prompt_text: String = "interagir":
	set(value):
		if prompt_text == value:
			return
		prompt_text = value
		prompt_changed.emit()
## Quando falso, o objeto é ignorado pelo raio (sem mensagem na tela).
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		prompt_changed.emit()
## Tempo mínimo entre duas interações (evita "metralhar" a tecla E).
@export_range(0.0, 2.0, 0.05) var cooldown: float = 0.2

var _last_interaction_ms: int = -100000

## MULTIPLAYER: parâmetros decididos pelo HOST para esta interação (ex.: para
## que lado a porta abre). Válido apenas durante `_on_interact`/`interacted`.
var last_net_params: Dictionary = {}
## Opcional: função (interactor) -> Dictionary chamada SÓ no host, antes de
## repassar a interação a todos. Ex.: a Porta escolhe o sentido de abertura.
var net_params_provider: Callable


func _init() -> void:
	# A área só precisa ser "vista" pelo raio; não monitora nada sozinha,
	# então não gasta processamento de sobreposição.
	collision_layer = 1 << (INTERACTABLE_LAYER - 1)
	collision_mask = 0
	monitoring = false
	monitorable = true


## Texto do verbo (sem o "Pressione E"). Sobrescreva para textos dinâmicos.
func get_prompt() -> String:
	return prompt_text


## Retorna se este interator pode interagir agora.
func can_interact(_interactor: Node) -> bool:
	return enabled and is_inside_tree()


## Chamado pelo Interactor. Não sobrescreva; use `_on_interact`.
func interact(interactor: Node) -> bool:
	if not can_interact(interactor):
		return false
	var now := Time.get_ticks_msec()
	if now - _last_interaction_ms < int(cooldown * 1000.0):
		return false
	_last_interaction_ms = now
	_on_interact(interactor)
	interacted.emit(interactor)
	return true


## Verdadeiro se ainda está no intervalo mínimo entre interações.
func is_on_cooldown() -> bool:
	return Time.get_ticks_msec() - _last_interaction_ms < int(cooldown * 1000.0)


## MULTIPLAYER (só no host): dados extras que todos devem usar ao executar.
func get_net_params(interactor: Node) -> Dictionary:
	if net_params_provider.is_valid():
		return net_params_provider.call(interactor)
	return {}


## MULTIPLAYER: executa uma interação JÁ VALIDADA pelo host. Chamado em todos
## os computadores, na mesma ordem, pelo autoload Net.
func interact_networked(interactor: Node, params: Dictionary) -> void:
	_last_interaction_ms = Time.get_ticks_msec()
	last_net_params = params
	_on_interact(interactor)
	interacted.emit(interactor)
	last_net_params = {}


## MULTIPLAYER: estado completo enviado pelo host para corrigir diferenças.
## Sobrescreva em interativos com estado (o padrão não faz nada).
func apply_net_state(state: Dictionary) -> void:
	# Interativos "de apoio" (ex.: a área da porta) repassam ao dono.
	var t: Variant = get_meta(&"net_state_target", null)
	if t != null and is_instance_valid(t) and t.has_method(&"apply_net_state"):
		t.call(&"apply_net_state", state)


## Ponto de extensão para subclasses.
func _on_interact(_interactor: Node) -> void:
	pass
