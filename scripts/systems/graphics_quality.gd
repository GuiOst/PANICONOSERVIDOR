class_name GraphicsQuality
extends WorldEnvironment
## Aplica o preset de qualidade gráfica (Baixa/Média/Alta) escolhido em
## GameSettings ao ambiente e ao viewport.
##
## Fica no nó WorldEnvironment da cena principal. Luzes que só devem ter
## sombra em qualidade alta precisam estar no grupo "quality_shadow_light".
##
## Ajuste fino (o que cada preset liga/desliga):
##  LOW    -> escala 3D 75% (FSR), sem SSAO/SSIL, sem névoa volumétrica,
##            sem glow, sombras só na lanterna.
##  MEDIUM -> escala 100%, SSAO, glow, névoa volumétrica leve,
##            sombras nas luzes principais.
##  HIGH   -> MEDIUM + SSIL, névoa volumétrica mais detalhada, MSAA 2x.

const SHADOW_LIGHT_GROUP := &"quality_shadow_light"


func _ready() -> void:
	GameSettings.settings_changed.connect(apply)
	# Espera um frame para que todas as luzes da fase já estejam na árvore.
	apply.call_deferred()


func apply() -> void:
	if environment == null:
		return
	var q: int = GameSettings.graphics_quality
	var vp := get_viewport()

	environment.ssao_enabled = q >= GameSettings.Quality.MEDIUM
	environment.ssil_enabled = q >= GameSettings.Quality.HIGH
	environment.glow_enabled = q >= GameSettings.Quality.MEDIUM
	environment.volumetric_fog_enabled = q >= GameSettings.Quality.MEDIUM
	# A névoa comum (barata) fica ligada em todos os níveis para manter o clima.
	environment.fog_enabled = true

	if vp:
		vp.msaa_3d = Viewport.MSAA_2X if q >= GameSettings.Quality.HIGH else Viewport.MSAA_DISABLED
		if q == GameSettings.Quality.LOW:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.75
		else:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0

	# Detalhe da névoa volumétrica (configuração global do servidor de render).
	if q >= GameSettings.Quality.HIGH:
		RenderingServer.environment_set_volumetric_fog_volume_size(96, 96)
	else:
		RenderingServer.environment_set_volumetric_fog_volume_size(64, 48)

	var shadows := q >= GameSettings.Quality.MEDIUM
	for node in get_tree().get_nodes_in_group(SHADOW_LIGHT_GROUP):
		if node is Light3D:
			(node as Light3D).shadow_enabled = shadows
