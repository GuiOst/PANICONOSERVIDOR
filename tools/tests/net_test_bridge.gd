extends Node
## SÓ PARA TESTES: canal de mensagens entre as instâncias de teste
## (não faz parte do jogo; a pasta tools/ não vai para a exportação).

var data: Dictionary = {}


func put(key: String, value: Variant) -> void:
	data[key] = value
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_rpc_put.rpc(key, value)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_put(key: String, value: Variant) -> void:
	data[key] = value


func count_prefix(prefix: String) -> int:
	var n := 0
	for k in data.keys():
		if String(k).begins_with(prefix):
			n += 1
	return n
