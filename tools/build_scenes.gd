extends SceneTree
## =========================================================================
## CONSTRUTOR DE CENAS — Pânico no Servidor (ferramenta de desenvolvimento)
## =========================================================================
## Gera, a partir de código, os materiais, os objetos de cenário (props), a
## porta industrial e a fase "facility_level.tscn".
##
## Você NÃO precisa rodar isto para jogar: as cenas geradas já fazem parte
## do projeto e podem ser editadas normalmente no editor do Godot.
##
## ATENÇÃO: rodar de novo SOBRESCREVE as cenas geradas (e as edições manuais
## feitas nelas). Uso (terminal, na pasta do projeto):
##   godot --headless --path . --script res://tools/build_scenes.gd
## =========================================================================

const MAT_DIR := "res://assets/materials/"
const PROPS_DIR := "res://scenes/environment/props/"
const TEX := "res://assets/textures/"

var M := {}                 # materiais por nome
var _mesh_cache := {}       # reaproveita meshes iguais (menos memória)
var _font_bold: FontFile
var _root: Node             # raiz da cena em construção (para o owner)


func _initialize() -> void:
	_font_bold = load("res://assets/fonts/DejaVuSansMono-Bold.ttf")
	_make_materials()
	_build_props()
	_build_door()
	_build_level()
	print("[build_scenes] Concluído.")
	quit()


# =========================================================================
# MATERIAIS
# =========================================================================
func _tex(name: String) -> Texture2D:
	var p := TEX + name
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


func _pbr(name: String, base: String, color: Color, rough: float, metal: float,
		world: bool, scale: float, normal_strength: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.4
	if base != "":
		m.albedo_texture = _tex(base + "_albedo.png")
		var n := _tex(base + "_normal.png")
		if n:
			m.normal_enabled = true
			m.normal_texture = n
			m.normal_scale = normal_strength
		var r := _tex(base + "_rough.png")
		if r:
			m.roughness_texture = r
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
		# Triplanar: projeta a textura sem depender de UVs (perfeito para
		# blocos simples). "world" = textura fixa no mundo (paredes contínuas).
		m.uv1_triplanar = true
		m.uv1_world_triplanar = world
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE * scale
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _save_mat(name, m)


func _flat(name: String, color: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return _save_mat(name, m)


func _emissive(name: String, color: Color, energy: float, albedo: Color = Color(0.1, 0.1, 0.1)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return _save_mat(name, m)


func _save_mat(name: String, m: StandardMaterial3D) -> StandardMaterial3D:
	var path := MAT_DIR + name + ".tres"
	var err := ResourceSaver.save(m, path, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		push_error("Falha ao salvar material %s" % path)
	# Recarrega do disco: assim as cenas REFERENCIAM o .tres (um material
	# compartilhado) em vez de embutir uma cópia em cada cena.
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as StandardMaterial3D
	M[name] = loaded
	return loaded


func _make_materials() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAT_DIR))
	# Arquitetura (projeção no mundo: emendas invisíveis entre blocos)
	_pbr("concrete_wall", "concrete_wall", Color(0.78, 0.78, 0.76), 0.9, 0.0, true, 0.3, 1.2)
	_pbr("concrete_wall_dark", "concrete_wall", Color(0.42, 0.43, 0.42), 0.92, 0.0, true, 0.3, 1.2)
	_pbr("concrete_ceiling", "concrete_wall", Color(0.30, 0.30, 0.30), 0.95, 0.0, true, 0.25, 1.0)
	_pbr("concrete_floor", "floor_concrete", Color(0.85, 0.85, 0.85), 0.6, 0.0, true, 0.25, 1.0)
	_pbr("metal_plate_floor", "metal_plate", Color(0.8, 0.8, 0.8), 0.5, 0.75, true, 0.5, 1.0)
	_pbr("hazard_stripes", "hazard_stripes", Color(1, 1, 1), 0.75, 0.0, true, 1.2)
	# Metais e objetos (projeção local: a textura acompanha o objeto)
	_pbr("metal_painted_gray", "metal_painted", Color(0.38, 0.40, 0.41), 0.6, 0.35, false, 1.0)
	_pbr("metal_painted_green", "metal_painted", Color(0.20, 0.30, 0.25), 0.62, 0.3, false, 1.0)
	_pbr("metal_painted_blue", "metal_painted", Color(0.13, 0.22, 0.36), 0.6, 0.3, false, 1.0)
	_pbr("metal_painted_yellow", "metal_painted", Color(0.75, 0.55, 0.08), 0.6, 0.25, false, 1.0)
	_pbr("metal_painted_red", "metal_painted", Color(0.45, 0.07, 0.05), 0.6, 0.25, false, 1.0)
	_pbr("metal_door", "metal_painted", Color(0.28, 0.33, 0.30), 0.55, 0.4, false, 0.8)
	_pbr("metal_rusty", "metal_rusty", Color(1, 1, 1), 0.7, 0.6, false, 1.0)
	_pbr("metal_rusty_world", "metal_rusty", Color(1, 1, 1), 0.7, 0.6, true, 0.6)
	_pbr("wood_crate", "wood_crate", Color(0.9, 0.85, 0.8), 0.85, 0.0, false, 1.0)
	_flat("metal_dark", Color(0.08, 0.085, 0.09), 0.5, 0.8)
	_flat("metal_bare", Color(0.45, 0.46, 0.47), 0.35, 0.9)
	_flat("rubber_black", Color(0.025, 0.025, 0.025), 0.8)
	_flat("plastic_gray", Color(0.25, 0.25, 0.24), 0.6)
	_flat("sign_white", Color(0.75, 0.74, 0.70), 0.7)
	_flat("sign_yellow", Color(0.78, 0.60, 0.08), 0.7)
	_flat("sign_red", Color(0.50, 0.06, 0.05), 0.7)
	_flat("paint_yellow_line", Color(0.65, 0.50, 0.08), 0.8)
	_flat("grate_dark", Color(0.03, 0.03, 0.03), 0.9)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.07, 0.07, 0.75)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.15
	glass.metallic = 0.3
	_save_mat("glass_dirty", glass)
	_emissive("lamp_tube", Color(0.80, 0.90, 1.0), 5.0, Color(0.9, 0.95, 1.0))
	_emissive("lamp_tube_warm", Color(1.0, 0.85, 0.65), 4.0, Color(1.0, 0.95, 0.9))
	_emissive("emergency_lens", Color(1.0, 0.08, 0.04), 6.0, Color(0.5, 0.05, 0.05))
	_emissive("led_green", Color(0.2, 1.0, 0.3), 3.0)
	_emissive("led_red", Color(1.0, 0.1, 0.05), 3.0)
	_emissive("led_amber", Color(1.0, 0.6, 0.1), 2.5)
	_emissive("screen_green", Color(0.15, 0.55, 0.25), 1.6, Color(0.02, 0.05, 0.03))


# =========================================================================
# AJUDANTES DE GEOMETRIA
# =========================================================================
func _own(n: Node) -> void:
	n.owner = _root


func _add(parent: Node, n: Node, name: String = "") -> Node:
	if name != "":
		n.name = name
	parent.add_child(n, true)
	_own(n)
	return n


func _box_mesh(size: Vector3, mat: Material) -> BoxMesh:
	var key := "box_%s_%s" % [size, mat.resource_path]
	if not _mesh_cache.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		bm.material = mat
		_mesh_cache[key] = bm
	return _mesh_cache[key]


func _cyl_mesh(radius: float, height: float, mat: Material, sides: int = 16) -> CylinderMesh:
	var key := "cyl_%s_%s_%s_%s" % [radius, height, mat.resource_path, sides]
	if not _mesh_cache.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = radius
		cm.bottom_radius = radius
		cm.height = height
		cm.radial_segments = sides
		cm.rings = 1
		cm.material = mat
		_mesh_cache[key] = cm
	return _mesh_cache[key]


## Bloco visual (MeshInstance3D). `rot` em graus.
func box(parent: Node, name: String, size: Vector3, pos: Vector3, mat_name: String,
		rot: Vector3 = Vector3.ZERO, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(size, M[mat_name])
	mi.position = pos
	mi.rotation_degrees = rot
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(parent, mi, name)
	return mi


## Cilindro visual. Eixo padrão = Y; use rot para deitar (x=90 -> eixo Z, z=90 -> eixo X).
func cyl(parent: Node, name: String, radius: float, height: float, pos: Vector3, mat_name: String,
		rot: Vector3 = Vector3.ZERO, shadows: bool = true, sides: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl_mesh(radius, height, M[mat_name], sides)
	mi.position = pos
	mi.rotation_degrees = rot
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(parent, mi, name)
	return mi


## Forma de colisão em caixa dentro de um corpo físico.
func col_box(body: Node, size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	cs.rotation_degrees = rot
	_add(body, cs, "Col")
	return cs


func col_cyl(body: Node, radius: float, height: float, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	cs.position = pos
	cs.rotation_degrees = rot
	_add(body, cs, "Col")


## Bloco sólido: visual + colisão no corpo indicado.
func solid(parent: Node, body: Node, name: String, size: Vector3, pos: Vector3, mat_name: String,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := box(parent, name, size, pos, mat_name, rot)
	col_box(body, size, pos, rot)
	return mi


func label3d(parent: Node, name: String, text: String, pos: Vector3, rot: Vector3, size_px: int,
		color: Color, pixel_size: float = 0.004) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font_bold
	l.font_size = size_px
	l.pixel_size = pixel_size
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees = rot
	l.shaded = true            # recebe luz: fica escuro no escuro
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_add(parent, l, name)
	return l


## Placa: chapa + texto (o tamanho da letra é calculado para caber na chapa).
## `yaw_deg`: 0 = placa virada para +Z.
func make_sign(parent: Node, name: String, text: String, pos: Vector3, yaw_deg: float, size: Vector2,
		plate_mat: String, text_color: Color) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = Vector3(0, yaw_deg, 0)
	_add(parent, n, name)
	box(n, "Plate", Vector3(size.x, size.y, 0.02), Vector3.ZERO, plate_mat, Vector3.ZERO, false)
	var lines := text.split("\n")
	var longest := 1
	for ln in lines:
		longest = maxi(longest, ln.length())
	# Fonte monoespaçada: largura do caractere ~0.6 em; altura da linha ~1.17 em.
	var em := minf(size.x * 0.88 / (0.602 * longest), size.y * 0.78 / (1.17 * lines.size()))
	label3d(n, "Text", text, Vector3(0, 0, 0.0115), Vector3.ZERO, 64, text_color, em / 64.0)
	return n


## Decalque de parede: `normal` aponta para fora da parede; a textura fica
## "em pé" (topo da imagem para cima). size = (largura, profundidade, altura).
func wall_decal(parent: Node, name: String, tex_name: String, pos: Vector3, normal: Vector3,
		size: Vector3, alpha: float = 1.0) -> Decal:
	var d := decal(parent, name, tex_name, pos, Vector3.ZERO, size, alpha)
	var y := normal.normalized()
	var z := Vector3.DOWN
	d.basis = Basis(y.cross(z), y, z)
	return d


func decal(parent: Node, name: String, tex_name: String, pos: Vector3, rot: Vector3, size: Vector3,
		alpha: float = 1.0) -> Decal:
	var d := Decal.new()
	d.texture_albedo = _tex(tex_name)
	d.size = size
	d.position = pos
	d.rotation_degrees = rot
	d.modulate = Color(1, 1, 1, alpha)
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.cull_mask = 1 # não projeta no jogador (camada visual 2 no futuro)
	_add(parent, d, name)
	return d


func instance(parent: Node, scene_path: String, name: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var ps := load(scene_path) as PackedScene
	var n := ps.instantiate() as Node3D
	n.position = pos
	n.rotation_degrees = Vector3(0, yaw_deg, 0)
	_add(parent, n, name)
	return n


func _save_scene(root: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack falhou: %s" % path)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	err = ResourceSaver.save(ps, path)
	if err != OK:
		push_error("save falhou: %s" % path)
	else:
		print("  salvo: ", path)
	root.free()


func _new_root(type: Variant, name: String) -> Node:
	var r: Node = type.new()
	r.name = name
	_root = r
	return r


func _looping_sound(parent: Node, name: String, path: String, pos: Vector3, volume_db: float,
		unit_size: float, max_dist: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.set_script(load("res://scripts/systems/looping_sound_3d.gd"))
	p.set(&"stream_path", path)
	p.position = pos
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = max_dist
	p.bus = &"Ambience"
	p.attenuation_filter_cutoff_hz = 6000.0
	_add(parent, p, name)
	return p


# =========================================================================
# PROPS (objetos reutilizáveis)
# =========================================================================
func _build_props() -> void:
	print("[build_scenes] Props...")
	_prop_crate_wood()
	_prop_crate_metal()
	_prop_barrel("barrel_blue", "metal_painted_blue", false)
	_prop_barrel("barrel_hazard", "metal_painted_yellow", true)
	_prop_barrel("barrel_rusty", "metal_rusty", false)
	_prop_pallet()
	_prop_shelf()
	_prop_locker()
	_prop_electrical_panel()
	_prop_breaker_panel()
	_prop_transformer()
	_prop_desk()
	_prop_chair()
	_prop_warning_stand()
	_prop_ceiling_lamp("ceiling_lamp", "lamp_tube", Color(0.80, 0.88, 1.0), 5.0)
	_prop_ceiling_lamp("ceiling_lamp_warm", "lamp_tube_warm", Color(1.0, 0.82, 0.62), 3.4)
	_prop_emergency_light()
	_prop_blast_door()


func _prop_crate_wood() -> void:
	var r := _new_root(StaticBody3D, "CrateWood")
	solid(r, r, "Body", Vector3(1, 1, 1), Vector3(0, 0.5, 0), "wood_crate")
	# Reforços nas arestas verticais e cintas horizontais
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(r, "Edge", Vector3(0.08, 1.0, 0.08), Vector3(0.47 * sx, 0.5, 0.47 * sz), "metal_dark", Vector3.ZERO, false)
	box(r, "BandTop", Vector3(1.02, 0.07, 1.02), Vector3(0, 0.9, 0), "metal_dark", Vector3.ZERO, false)
	box(r, "BandBottom", Vector3(1.02, 0.07, 1.02), Vector3(0, 0.1, 0), "metal_dark", Vector3.ZERO, false)
	label3d(r, "Stencil", "FRÁGIL", Vector3(0, 0.55, 0.512), Vector3.ZERO, 64, Color(0.1, 0.07, 0.04), 0.0028)
	_save_scene(r, PROPS_DIR + "crate_wood.tscn")


func _prop_crate_metal() -> void:
	var r := _new_root(StaticBody3D, "CrateMetal")
	solid(r, r, "Body", Vector3(0.7, 0.45, 0.45), Vector3(0, 0.225, 0), "metal_painted_green")
	box(r, "Lid", Vector3(0.72, 0.05, 0.47), Vector3(0, 0.45, 0), "metal_painted_green")
	box(r, "Latch", Vector3(0.08, 0.1, 0.02), Vector3(0, 0.37, 0.235), "metal_bare", Vector3.ZERO, false)
	label3d(r, "Stencil", "EQUIP. 07", Vector3(0, 0.2, 0.2265), Vector3.ZERO, 40, Color(0.8, 0.78, 0.7), 0.0025)
	_save_scene(r, PROPS_DIR + "crate_metal.tscn")


func _prop_barrel(file: String, mat: String, hazard: bool) -> void:
	var r := _new_root(StaticBody3D, "Barrel")
	cyl(r, "Body", 0.29, 0.9, Vector3(0, 0.45, 0), mat, Vector3.ZERO, true, 20)
	col_cyl(r, 0.3, 0.9, Vector3(0, 0.45, 0))
	for y in [0.06, 0.32, 0.6, 0.86]:
		cyl(r, "Ring", 0.3, 0.035, Vector3(0, y, 0), "metal_dark", Vector3.ZERO, false, 20)
	cyl(r, "Lid", 0.27, 0.01, Vector3(0, 0.905, 0), "metal_dark", Vector3.ZERO, false, 20)
	cyl(r, "Cap", 0.04, 0.03, Vector3(0.15, 0.915, 0), "metal_bare", Vector3.ZERO, false, 8)
	if hazard:
		cyl(r, "HazardBand", 0.292, 0.16, Vector3(0, 0.46, 0), "hazard_stripes", Vector3.ZERO, false, 20)
	_save_scene(r, PROPS_DIR + file + ".tscn")


func _prop_pallet() -> void:
	var r := _new_root(StaticBody3D, "Pallet")
	col_box(r, Vector3(1.2, 0.14, 1.0), Vector3(0, 0.07, 0))
	for i in 5:
		box(r, "Slat", Vector3(1.2, 0.025, 0.14), Vector3(0, 0.1275, -0.43 + i * 0.215), "wood_crate", Vector3.ZERO, false)
	for i in 3:
		box(r, "Runner", Vector3(0.1, 0.115, 1.0), Vector3(-0.55 + i * 0.55, 0.0575, 0), "wood_crate", Vector3.ZERO, false)
	_save_scene(r, PROPS_DIR + "pallet.tscn")


func _prop_shelf() -> void:
	var r := _new_root(StaticBody3D, "Shelf")
	var w := 2.0
	var d := 0.6
	var h := 2.2
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			solid(r, r, "Post", Vector3(0.05, h, 0.05), Vector3((w / 2 - 0.025) * sx, h / 2, (d / 2 - 0.025) * sz), "metal_painted_blue")
	for y in [0.12, 0.8, 1.45, 2.1]:
		solid(r, r, "Board", Vector3(w, 0.03, d), Vector3(0, y, 0), "metal_painted_gray")
		box(r, "Lip", Vector3(w, 0.06, 0.02), Vector3(0, y, d / 2), "metal_painted_blue", Vector3.ZERO, false)
	# Travamento em X nas costas
	box(r, "Brace", Vector3(0.02, 2.3, 0.02), Vector3(0, 1.1, -d / 2 + 0.01), "metal_dark", Vector3(0, 0, 41), false)
	box(r, "Brace2", Vector3(0.02, 2.3, 0.02), Vector3(0, 1.1, -d / 2 + 0.01), "metal_dark", Vector3(0, 0, -41), false)
	_save_scene(r, PROPS_DIR + "shelf.tscn")


func _prop_locker() -> void:
	var r := _new_root(StaticBody3D, "Locker")
	solid(r, r, "Body", Vector3(0.5, 1.9, 0.5), Vector3(0, 0.95, 0), "metal_painted_gray")
	box(r, "Door", Vector3(0.44, 1.8, 0.02), Vector3(0, 0.97, 0.255), "metal_painted_gray")
	for i in 5:
		box(r, "Vent", Vector3(0.28, 0.015, 0.01), Vector3(0, 1.62 + i * 0.04, 0.267), "grate_dark", Vector3.ZERO, false)
	box(r, "Handle", Vector3(0.03, 0.12, 0.03), Vector3(0.16, 1.0, 0.28), "metal_bare", Vector3.ZERO, false)
	box(r, "NamePlate", Vector3(0.14, 0.05, 0.005), Vector3(0, 1.45, 0.2665), "sign_white", Vector3.ZERO, false)
	_save_scene(r, PROPS_DIR + "locker.tscn")


func _prop_electrical_panel() -> void:
	# Origem: atrás/embaixo, para encostar na parede (frente = +Z)
	var r := _new_root(StaticBody3D, "ElectricalPanel")
	solid(r, r, "Cabinet", Vector3(0.8, 1.2, 0.25), Vector3(0, 1.4, 0.125), "metal_painted_gray")
	box(r, "DoorSeam", Vector3(0.005, 1.1, 0.01), Vector3(0, 1.4, 0.252), "grate_dark", Vector3.ZERO, false)
	box(r, "HandleL", Vector3(0.025, 0.1, 0.03), Vector3(-0.05, 1.4, 0.265), "metal_bare", Vector3.ZERO, false)
	box(r, "HandleR", Vector3(0.025, 0.1, 0.03), Vector3(0.05, 1.4, 0.265), "metal_bare", Vector3.ZERO, false)
	var leds := ["led_green", "led_green", "led_amber", "led_red"]
	for i in leds.size():
		box(r, "Led", Vector3(0.025, 0.025, 0.01), Vector3(-0.3 + i * 0.05, 1.93, 0.255), leds[i], Vector3.ZERO, false)
	make_sign(r, "Warning", "⚡ PERIGO\nALTA TENSÃO", Vector3(0.2, 1.75, 0.262), 0, Vector2(0.3, 0.16), "sign_yellow", Color(0.05, 0.05, 0.05))
	# Conduítes saindo por cima até o teto
	cyl(r, "Conduit1", 0.025, 1.6, Vector3(-0.25, 2.8, 0.1), "metal_bare", Vector3.ZERO, false, 8)
	cyl(r, "Conduit2", 0.025, 1.6, Vector3(0.25, 2.8, 0.1), "metal_bare", Vector3.ZERO, false, 8)
	_looping_sound(r, "Hum", "res://assets/audio/ambience/electrical_hum.wav", Vector3(0, 1.4, 0.3), -16.0, 1.5, 9.0)
	_save_scene(r, PROPS_DIR + "electrical_panel.tscn")


func _prop_breaker_panel() -> void:
	var r := _new_root(StaticBody3D, "BreakerPanel")
	solid(r, r, "Cabinet", Vector3(0.6, 0.8, 0.2), Vector3(0, 1.3, 0.1), "metal_painted_red")
	make_sign(r, "Label", "DISJUNTOR\nDEPÓSITO B", Vector3(0, 1.82, 0.012), 0, Vector2(0.5, 0.16), "sign_white", Color(0.08, 0.08, 0.08))
	box(r, "Slot", Vector3(0.12, 0.3, 0.01), Vector3(0, 1.3, 0.205), "grate_dark", Vector3.ZERO, false)
	# Alavanca (gira em X)
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 1.3, 0.22)
	_add(r, pivot, "LeverPivot")
	box(pivot, "Arm", Vector3(0.04, 0.22, 0.04), Vector3(0, 0.11, 0), "metal_bare", Vector3.ZERO, false)
	box(pivot, "Grip", Vector3(0.1, 0.05, 0.05), Vector3(0, 0.22, 0), "rubber_black", Vector3.ZERO, false)
	# Área de interação (script BreakerSwitch)
	var area := Area3D.new()
	area.set_script(load("res://scripts/interaction/breaker_switch.gd"))
	area.position = Vector3(0, 1.3, 0.15)
	_add(r, area, "BreakerSwitch")
	area.collision_layer = 1 << 2
	area.collision_mask = 0
	area.set(&"lever_path", NodePath("../LeverPivot"))
	area.set(&"circuit_group", &"circuit_storage")
	col_box(area, Vector3(0.65, 0.85, 0.3), Vector3.ZERO)
	var snd := AudioStreamPlayer3D.new()
	snd.bus = &"SFX"
	snd.unit_size = 3.0
	_add(area, snd, "SwitchAudio")
	_save_scene(r, PROPS_DIR + "breaker_panel.tscn")


func _prop_transformer() -> void:
	var r := _new_root(StaticBody3D, "Transformer")
	solid(r, r, "Body", Vector3(1.6, 1.8, 1.0), Vector3(0, 0.9, 0), "metal_painted_green")
	box(r, "Base", Vector3(1.75, 0.12, 1.15), Vector3(0, 0.06, 0), "metal_dark")
	for i in 7:
		box(r, "FinL", Vector3(0.12, 1.3, 0.03), Vector3(-0.86, 0.95, -0.36 + i * 0.12), "metal_painted_green", Vector3.ZERO, false)
		box(r, "FinR", Vector3(0.12, 1.3, 0.03), Vector3(0.86, 0.95, -0.36 + i * 0.12), "metal_painted_green", Vector3.ZERO, false)
	for i in 3:
		cyl(r, "Insulator", 0.06, 0.25, Vector3(-0.4 + i * 0.4, 1.92, 0.2), "plastic_gray", Vector3.ZERO, false, 10)
	make_sign(r, "Warning", "⚡ PERIGO DE MORTE\n13.8 kV", Vector3(0, 1.25, 0.511), 0, Vector2(0.62, 0.24), "sign_yellow", Color(0.05, 0.05, 0.05))
	box(r, "Plate", Vector3(0.3, 0.18, 0.01), Vector3(0.45, 0.6, 0.505), "metal_bare", Vector3.ZERO, false)
	_looping_sound(r, "Hum", "res://assets/audio/ambience/electrical_hum.wav", Vector3(0, 1.0, 0), -8.0, 2.5, 14.0)
	_save_scene(r, PROPS_DIR + "transformer.tscn")


func _prop_desk() -> void:
	var r := _new_root(StaticBody3D, "Desk")
	solid(r, r, "Top", Vector3(1.4, 0.04, 0.7), Vector3(0, 0.76, 0), "metal_painted_gray")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			solid(r, r, "Leg", Vector3(0.04, 0.74, 0.04), Vector3(0.66 * sx, 0.37, 0.31 * sz), "metal_dark")
	solid(r, r, "Drawers", Vector3(0.4, 0.55, 0.6), Vector3(0.45, 0.46, 0), "metal_painted_gray")
	# Terminal antigo (tela com brilho fraco)
	solid(r, r, "Monitor", Vector3(0.45, 0.38, 0.4), Vector3(-0.2, 0.97, -0.1), "plastic_gray")
	box(r, "Screen", Vector3(0.36, 0.27, 0.01), Vector3(-0.2, 0.98, 0.101), "screen_green", Vector3.ZERO, false)
	label3d(r, "ScreenText", "> SISTEMA OFFLINE_\n> ERRO 0x3F: NÓ B-2", Vector3(-0.2, 0.99, 0.107), Vector3.ZERO, 20, Color(0.5, 1.0, 0.6), 0.0014)
	box(r, "Keyboard", Vector3(0.42, 0.025, 0.15), Vector3(-0.2, 0.79, 0.2), "plastic_gray", Vector3(8, 0, 0), false)
	box(r, "Papers", Vector3(0.22, 0.01, 0.3), Vector3(0.3, 0.785, 0.1), "sign_white", Vector3(0, 12, 0), false)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.3, 1.0, 0.45)
	glow.light_energy = 0.35
	glow.omni_range = 1.6
	glow.position = Vector3(-0.2, 0.98, 0.3)
	glow.shadow_enabled = false
	_add(r, glow, "ScreenGlow")
	_save_scene(r, PROPS_DIR + "desk.tscn")


func _prop_chair() -> void:
	var r := _new_root(StaticBody3D, "Chair")
	solid(r, r, "Seat", Vector3(0.45, 0.05, 0.45), Vector3(0, 0.46, 0), "rubber_black")
	solid(r, r, "Back", Vector3(0.45, 0.45, 0.04), Vector3(0, 0.72, -0.21), "rubber_black", Vector3(-6, 0, 0))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(r, "Leg", Vector3(0.03, 0.45, 0.03), Vector3(0.2 * sx, 0.225, 0.2 * sz), "metal_bare", Vector3.ZERO, false)
	col_box(r, Vector3(0.45, 0.45, 0.45), Vector3(0, 0.225, 0))
	_save_scene(r, PROPS_DIR + "chair.tscn")


func _prop_warning_stand() -> void:
	var r := _new_root(StaticBody3D, "WarningStand")
	box(r, "BoardFront", Vector3(0.6, 0.9, 0.02), Vector3(0, 0.45, 0.13), "sign_yellow", Vector3(-15, 0, 0))
	box(r, "BoardBack", Vector3(0.6, 0.9, 0.02), Vector3(0, 0.45, -0.13), "sign_yellow", Vector3(15, 0, 0))
	label3d(r, "Text", "CUIDADO\nEM\nMANUTENÇÃO", Vector3(0, 0.48, 0.152), Vector3(-15, 0, 0), 48, Color(0.05, 0.05, 0.05), 0.0018)
	col_box(r, Vector3(0.6, 0.9, 0.35), Vector3(0, 0.45, 0))
	_save_scene(r, PROPS_DIR + "warning_stand.tscn")


func _prop_ceiling_lamp(file: String, tube_mat: String, color: Color, energy: float) -> void:
	# Origem = ponto de fixação no teto. A luminária pende 0.45 m.
	var r := _new_root(Node3D, "CeilingLamp")
	r.set_script(load("res://scripts/environment/ceiling_lamp.gd"))
	cyl(r, "RodL", 0.008, 0.38, Vector3(-0.5, -0.19, 0), "metal_dark", Vector3.ZERO, false, 6)
	cyl(r, "RodR", 0.008, 0.38, Vector3(0.5, -0.19, 0), "metal_dark", Vector3.ZERO, false, 6)
	box(r, "Housing", Vector3(1.3, 0.08, 0.26), Vector3(0, -0.41, 0), "metal_dark")
	box(r, "Reflector", Vector3(1.26, 0.01, 0.24), Vector3(0, -0.455, 0), "metal_bare", Vector3.ZERO, false)
	box(r, "Tube", Vector3(1.15, 0.045, 0.06), Vector3(0, -0.48, 0), tube_mat, Vector3.ZERO, false)
	var light := SpotLight3D.new()
	light.position = Vector3(0, -0.52, 0)
	light.rotation_degrees = Vector3(-90, 0, 0)
	light.light_color = color
	light.light_energy = energy
	light.spot_range = 8.5
	light.spot_angle = 62.0
	light.spot_angle_attenuation = 0.8
	light.spot_attenuation = 0.7
	light.light_volumetric_fog_energy = 0.6
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 1.5
	light.distance_fade_enabled = true
	light.distance_fade_begin = 30.0
	light.distance_fade_length = 8.0
	light.add_to_group(&"quality_shadow_light", true)
	_add(r, light, "Light")
	# Luz de preenchimento fraca para o teto não ficar 100% preto.
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, -0.3, 0)
	fill.light_color = color
	fill.light_energy = energy * 0.08
	fill.omni_range = 3.0
	fill.shadow_enabled = false
	_add(light, fill, "Fill") # filho da luz: apaga junto com ela
	fill.position = Vector3(0, 0, 0.3) # +Z local da spot = para cima (ilumina o teto)
	_looping_sound(r, "Buzz", "res://assets/audio/ambience/lamp_buzz.wav", Vector3(0, -0.45, 0), -20.0, 1.0, 6.0)
	_save_scene(r, PROPS_DIR + file + ".tscn")


func _prop_emergency_light() -> void:
	var r := _new_root(Node3D, "EmergencyLight")
	r.set_script(load("res://scripts/environment/emergency_light.gd"))
	box(r, "Base", Vector3(0.24, 0.06, 0.1), Vector3(0, 0, 0.05), "metal_dark")
	cyl(r, "Lens", 0.07, 0.12, Vector3(0, -0.08, 0.06), "emergency_lens", Vector3.ZERO, false, 12)
	var light := OmniLight3D.new()
	light.position = Vector3(0, -0.12, 0.25)
	light.light_color = Color(1.0, 0.12, 0.06)
	light.light_energy = 1.0
	light.omni_range = 4.0
	light.omni_attenuation = 1.2
	light.light_volumetric_fog_energy = 1.5
	light.shadow_enabled = false
	_add(r, light, "Light")
	_save_scene(r, PROPS_DIR + "emergency_light.tscn")


func _prop_blast_door() -> void:
	# Portão pesado de setor (decorativo, trancado). Origem no chão, centro.
	var r := _new_root(StaticBody3D, "BlastDoor")
	solid(r, r, "FrameL", Vector3(0.4, 3.2, 0.5), Vector3(-1.6, 1.6, 0), "metal_painted_gray")
	solid(r, r, "FrameR", Vector3(0.4, 3.2, 0.5), Vector3(1.6, 1.6, 0), "metal_painted_gray")
	solid(r, r, "FrameTop", Vector3(3.6, 0.4, 0.5), Vector3(0, 3.0, 0), "metal_painted_gray")
	solid(r, r, "LeafL", Vector3(1.4, 2.8, 0.25), Vector3(-0.7, 1.4, 0.05), "metal_door")
	solid(r, r, "LeafR", Vector3(1.4, 2.8, 0.25), Vector3(0.7, 1.4, 0.05), "metal_door")
	box(r, "Seam", Vector3(0.02, 2.8, 0.27), Vector3(0, 1.4, 0.05), "grate_dark", Vector3.ZERO, false)
	for y in [0.4, 1.4, 2.4]:
		box(r, "RibL", Vector3(1.3, 0.12, 0.05), Vector3(-0.7, y, 0.2), "metal_dark")
		box(r, "RibR", Vector3(1.3, 0.12, 0.05), Vector3(0.7, y, 0.2), "metal_dark")
	box(r, "HazardL", Vector3(0.36, 3.0, 0.01), Vector3(-1.6, 1.5, 0.256), "hazard_stripes", Vector3.ZERO, false)
	box(r, "HazardR", Vector3(0.36, 3.0, 0.01), Vector3(1.6, 1.5, 0.256), "hazard_stripes", Vector3.ZERO, false)
	box(r, "HazardTop", Vector3(2.8, 0.3, 0.01), Vector3(0, 3.0, 0.256), "hazard_stripes", Vector3.ZERO, false)
	box(r, "KeypadBox", Vector3(0.2, 0.3, 0.06), Vector3(1.6, 1.3, 0.28), "metal_dark")
	box(r, "KeypadLed", Vector3(0.04, 0.04, 0.01), Vector3(1.6, 1.4, 0.312), "led_red", Vector3.ZERO, false)
	_save_scene(r, PROPS_DIR + "blast_door.tscn")


# =========================================================================
# PORTA INDUSTRIAL (interativa)
# =========================================================================
func _build_door() -> void:
	print("[build_scenes] Porta...")
	var r := _new_root(Node3D, "IndustrialDoor")
	r.set_script(load("res://scripts/interaction/door.gd"))
	# Abertura: 1.4 m x 2.4 m. Batente externo: 1.7 m x 2.55 m (cabe no vão da parede).
	var frame := StaticBody3D.new()
	_add(r, frame, "Frame")
	solid(frame, frame, "JambL", Vector3(0.15, 2.55, 0.36), Vector3(-0.775, 1.275, 0), "metal_painted_gray")
	solid(frame, frame, "JambR", Vector3(0.15, 2.55, 0.36), Vector3(0.775, 1.275, 0), "metal_painted_gray")
	solid(frame, frame, "Header", Vector3(1.7, 0.15, 0.36), Vector3(0, 2.475, 0), "metal_painted_gray")
	for side in [-1, 1]:
		box(frame, "StripeL", Vector3(0.15, 2.4, 0.005), Vector3(-0.775, 1.2, 0.183 * side), "hazard_stripes", Vector3.ZERO, false)
		box(frame, "StripeR", Vector3(0.15, 2.4, 0.005), Vector3(0.775, 1.2, 0.183 * side), "hazard_stripes", Vector3.ZERO, false)
	# Folha: origem NA DOBRADIÇA (lado esquerdo da abertura)
	var panel := AnimatableBody3D.new()
	panel.position = Vector3(-0.7, 0, 0)
	panel.sync_to_physics = true
	_add(r, panel, "Panel")
	var pw := 1.38
	var ph := 2.37
	box(panel, "Leaf", Vector3(pw, ph, 0.08), Vector3(pw / 2 + 0.01, ph / 2 + 0.015, 0), "metal_door")
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(pw, ph, 0.08)
	shape.shape = bs
	shape.position = Vector3(pw / 2 + 0.01, ph / 2 + 0.015, 0)
	_add(panel, shape, "PanelShape")
	for side in [-1, 1]:
		for y in [0.45, 1.95]:
			box(panel, "Rib", Vector3(1.2, 0.09, 0.02), Vector3(pw / 2 + 0.01, y, 0.05 * side), "metal_dark")
		box(panel, "KickPlate", Vector3(1.2, 0.25, 0.01), Vector3(pw / 2 + 0.01, 0.17, 0.045 * side), "hazard_stripes", Vector3.ZERO, false)
		cyl(panel, "Handle", 0.018, 0.16, Vector3(1.22, 1.05, 0.07 * side), "metal_bare", Vector3.ZERO, false, 8)
		box(panel, "HandleBase", Vector3(0.05, 0.22, 0.02), Vector3(1.22, 1.05, 0.045 * side), "metal_dark", Vector3.ZERO, false)
	box(panel, "Window", Vector3(0.32, 0.42, 0.09), Vector3(pw / 2 + 0.01, 1.55, 0), "glass_dirty", Vector3.ZERO, false)
	box(panel, "WindowFrameT", Vector3(0.38, 0.03, 0.1), Vector3(pw / 2 + 0.01, 1.775, 0), "metal_dark", Vector3.ZERO, false)
	box(panel, "WindowFrameB", Vector3(0.38, 0.03, 0.1), Vector3(pw / 2 + 0.01, 1.325, 0), "metal_dark", Vector3.ZERO, false)
	label3d(panel, "LabelFront", "ACESSO RESTRITO", Vector3(pw / 2 + 0.01, 1.2, 0.041), Vector3.ZERO, 32, Color(0.85, 0.82, 0.7), 0.003)
	label3d(panel, "LabelBack", "ACESSO RESTRITO", Vector3(pw / 2 + 0.01, 1.2, -0.041), Vector3(0, 180, 0), 32, Color(0.85, 0.82, 0.7), 0.003)
	# Área de interação: mais grossa que a folha para o raio acertá-la primeiro.
	var area := Area3D.new()
	area.set_script(load("res://scripts/interaction/interactable.gd"))
	_add(panel, area, "InteractArea")
	area.collision_layer = 1 << 2
	area.collision_mask = 0
	area.set(&"prompt_text", "abrir")
	var ashape := CollisionShape3D.new()
	var abs_ := BoxShape3D.new()
	abs_.size = Vector3(pw, ph, 0.3)
	ashape.shape = abs_
	ashape.position = Vector3(pw / 2 + 0.01, ph / 2 + 0.015, 0)
	_add(area, ashape, "AreaShape")
	# Sons sincronizados com o movimento (trinco, rangido, batida)
	var sounds := Node3D.new()
	sounds.set_script(load("res://scripts/interaction/door_audio.gd"))
	_add(panel, sounds, "DoorSounds")
	_save_scene(r, "res://scenes/interactables/industrial_door.tscn")


# =========================================================================
# FASE: Setor B-2 (corredor + escritório de manutenção + depósito técnico)
# =========================================================================
## Planta (vista de cima, -Z = frente do jogador ao nascer):
##
##   z=+2   [elevador lacrado]  <- nascimento (0, 0, 0.5)
##          |   corredor 4 m   |
##   z=-10.5 PORTA ->[Escritório de manutenção]  (x -9..-2.3)
##          |                  |
##   z=-21.5        [Depósito / sala técnica]<- PORTA (x 2.3..11)
##          |                  |
##   z=-32  [portão do Setor C, trancado]
const CH := 3.6    # altura do corredor
const RA_H := 3.2  # altura do escritório
const RB_H := 3.4  # altura do depósito
const T := 0.3     # espessura das paredes

var _col: StaticBody3D  # todas as colisões da arquitetura num só corpo


func _build_level() -> void:
	print("[build_scenes] Fase...")
	var r := _new_root(Node3D, "FacilityLevel")
	var arch := Node3D.new()
	_add(r, arch, "Architecture")
	_col = StaticBody3D.new()
	_add(r, _col, "ArchitectureCollision")

	_build_shell(arch)
	_build_corridor_details(r)
	_build_maintenance_room(r)
	_build_storage_room(r)
	_build_lights(r)
	_build_wear(r)
	_build_gameplay_nodes(r)
	_save_scene(r, "res://scenes/environment/facility_level.tscn")


func _wall(parent: Node, name: String, center: Vector3, size: Vector3, mat: String = "concrete_wall") -> void:
	solid(parent, _col, name, size, center, mat)


func _build_shell(a: Node) -> void:
	# --- Pisos ---
	_wall(a, "FloorCorridor", Vector3(0, -0.15, -15.0), Vector3(4.6, 0.3, 34.6), "concrete_floor")
	_wall(a, "FloorMaintenance", Vector3(-5.8, -0.15, -10.5), Vector3(7.0, 0.3, 7.6), "concrete_floor")
	_wall(a, "FloorStorage", Vector3(6.8, -0.15, -21.5), Vector3(9.0, 0.3, 9.6), "concrete_floor")
	# --- Tetos ---
	_wall(a, "CeilingCorridor", Vector3(0, CH + 0.15, -15.0), Vector3(4.6, 0.3, 34.6), "concrete_ceiling")
	_wall(a, "CeilingMaintenance", Vector3(-5.8, RA_H + 0.15, -10.5), Vector3(7.0, 0.3, 7.6), "concrete_ceiling")
	_wall(a, "CeilingStorage", Vector3(6.8, RB_H + 0.15, -21.5), Vector3(9.0, 0.3, 9.6), "concrete_ceiling")
	# --- Corredor: parede esquerda (x = -2.15) com vão em z -11.35..-9.65 ---
	_wall(a, "CorridorL_A", Vector3(-2.15, CH / 2, (2.3 + -9.65) / 2), Vector3(T, CH, 2.3 + 9.65))
	_wall(a, "CorridorL_B", Vector3(-2.15, CH / 2, (-11.35 + -32.3) / 2), Vector3(T, CH, 32.3 - 11.35))
	_wall(a, "CorridorL_Lintel", Vector3(-2.15, (2.55 + CH) / 2, -10.5), Vector3(T, CH - 2.55, 1.7))
	# --- Corredor: parede direita (x = 2.15) com vão em z -22.35..-20.65 ---
	_wall(a, "CorridorR_A", Vector3(2.15, CH / 2, (2.3 + -20.65) / 2), Vector3(T, CH, 2.3 + 20.65))
	_wall(a, "CorridorR_B", Vector3(2.15, CH / 2, (-22.35 + -32.3) / 2), Vector3(T, CH, 32.3 - 22.35))
	_wall(a, "CorridorR_Lintel", Vector3(2.15, (2.55 + CH) / 2, -21.5), Vector3(T, CH - 2.55, 1.7))
	# --- Fundos ---
	_wall(a, "CorridorBack", Vector3(0, CH / 2, 2.15), Vector3(4.6, CH, T))
	_wall(a, "CorridorEnd", Vector3(0, CH / 2, -32.15), Vector3(4.6, CH, T))
	# --- Escritório de manutenção ---
	_wall(a, "MaintN", Vector3(-5.8, RA_H / 2, -6.85), Vector3(7.0, RA_H, T))
	_wall(a, "MaintS", Vector3(-5.8, RA_H / 2, -14.15), Vector3(7.0, RA_H, T))
	_wall(a, "MaintW", Vector3(-9.15, RA_H / 2, -10.5), Vector3(T, RA_H, 7.6))
	# --- Depósito / sala técnica ---
	_wall(a, "StorN", Vector3(6.8, RB_H / 2, -16.85), Vector3(9.0, RB_H, T))
	_wall(a, "StorS", Vector3(6.8, RB_H / 2, -26.15), Vector3(9.0, RB_H, T))
	_wall(a, "StorE", Vector3(11.15, RB_H / 2, -21.5), Vector3(T, RB_H, 9.6))
	# Rodapé escuro (sujeira acumulada) no corredor
	box(a, "BaseboardL", Vector3(0.02, 0.25, 34.0), Vector3(-1.995, 0.125, -15.0), "concrete_wall_dark", Vector3.ZERO, false)
	box(a, "BaseboardR", Vector3(0.02, 0.25, 34.0), Vector3(1.995, 0.125, -15.0), "concrete_wall_dark", Vector3.ZERO, false)


func _build_corridor_details(r: Node) -> void:
	var d := Node3D.new()
	_add(r, d, "CorridorDetails")
	# --- Pilares e vigas a cada 4 m (ritmo estrutural) ---
	var pillars := Node3D.new()
	_add(d, pillars, "Pillars")
	for i in 8:
		var z := 0.0 - i * 4.0
		box(pillars, "Beam", Vector3(4.0, 0.35, 0.35), Vector3(0, CH - 0.175, z), "concrete_wall_dark")
		for side in [-1, 1]:
			var x := 1.85 * float(side)
			# Não colocar pilar dentro dos vãos das portas
			if side == -1 and absf(z - -10.5) < 1.4:
				continue
			if side == 1 and absf(z - -21.5) < 1.4:
				continue
			solid(pillars, _col, "Pillar", Vector3(0.3, CH, 0.4), Vector3(x, CH / 2, z), "concrete_wall")
	# --- Tubulação ao longo da parede direita ---
	var pipes := Node3D.new()
	_add(d, pipes, "Pipes")
	var pipe_defs := [[0.11, 1.68, 2.98, "metal_rusty_world"], [0.07, 1.45, 3.1, "metal_painted_blue"], [0.05, 1.78, 2.74, "metal_painted_red"]]
	for p in pipe_defs:
		cyl(pipes, "Pipe", p[0], 34.0, Vector3(p[1], p[2], -15.0), p[3], Vector3(90, 0, 0), true, 12)
		for i in 9:
			cyl(pipes, "Flange", p[0] + 0.025, 0.06, Vector3(p[1], p[2], -2.0 - i * 4.0), "metal_dark", Vector3(90, 0, 0), false, 12)
	for i in 9:
		var z := -2.0 - i * 4.0
		box(pipes, "Bracket", Vector3(0.6, 0.04, 0.06), Vector3(1.7, 2.66, z), "metal_dark", Vector3.ZERO, false)
		box(pipes, "BracketPost", Vector3(0.04, 0.6, 0.06), Vector3(1.98, 2.95, z), "metal_dark", Vector3.ZERO, false)
	# Válvula vermelha
	cyl(pipes, "ValveStem", 0.02, 0.2, Vector3(1.68, 2.79, -6.0), "metal_bare", Vector3.ZERO, false, 8)
	cyl(pipes, "ValveWheel", 0.12, 0.025, Vector3(1.6, 2.69, -6.0), "metal_painted_red", Vector3.ZERO, false, 16)
	# --- Eletrocalha com cabos na parede esquerda ---
	var cables := Node3D.new()
	_add(d, cables, "Cables")
	box(cables, "Tray", Vector3(0.4, 0.04, 34.0), Vector3(-1.75, 3.0, -15.0), "metal_bare")
	box(cables, "TrayLipIn", Vector3(0.02, 0.08, 34.0), Vector3(-1.56, 3.04, -15.0), "metal_bare", Vector3.ZERO, false)
	for i in 4:
		cyl(cables, "Cable", 0.018 + 0.006 * (i % 2), 34.0, Vector3(-1.88 + i * 0.09, 3.04, -15.0), "rubber_black", Vector3(90, 0, 0), false, 6)
	# Cabos soltos pendendo (curvas feitas com segmentos)
	_droop_cable(cables, Vector3(-1.65, 3.0, -15.5), Vector3(-1.65, 3.0, -19.0), 0.55)
	_droop_cable(cables, Vector3(-1.75, 3.0, -24.0), Vector3(-1.6, 3.0, -27.5), 0.85)
	_droop_cable(cables, Vector3(1.6, 3.05, -12.5), Vector3(0.2, 3.5, -12.8), 0.6)
	# --- Duto de ventilação no teto ---
	var vent := Node3D.new()
	_add(d, vent, "VentDuct")
	box(vent, "Duct", Vector3(0.8, 0.45, 34.0), Vector3(-0.75, 3.0, -15.0), "metal_bare")
	for i in 17:
		box(vent, "Joint", Vector3(0.86, 0.5, 0.05), Vector3(-0.75, 3.0, 1.0 - i * 2.0), "metal_dark", Vector3.ZERO, false)
	for i in 4:
		box(vent, "Grille", Vector3(0.5, 0.01, 0.4), Vector3(-0.75, 2.77, -4.0 - i * 7.5), "grate_dark", Vector3.ZERO, false)
	# Grelha de ventilação na parede (perto do fim, de onde vem "o vento")
	box(d, "WallVent", Vector3(0.02, 0.6, 0.9), Vector3(-1.99, 0.6, -29.0), "grate_dark", Vector3.ZERO, false)
	for i in 6:
		box(d, "WallVentSlat", Vector3(0.03, 0.02, 0.86), Vector3(-1.98, 0.36 + i * 0.09, -29.0), "metal_dark", Vector3.ZERO, false)
	# --- Pintura de piso: faixas laterais e listras de perigo nas portas ---
	var paint := Node3D.new()
	_add(d, paint, "FloorPaint")
	box(paint, "LineL", Vector3(0.08, 0.004, 33.5), Vector3(-1.55, 0.002, -15.0), "paint_yellow_line", Vector3.ZERO, false)
	box(paint, "LineR", Vector3(0.08, 0.004, 33.5), Vector3(1.55, 0.002, -15.0), "paint_yellow_line", Vector3.ZERO, false)
	box(paint, "HazardDoorA", Vector3(1.2, 0.004, 1.8), Vector3(-1.4, 0.003, -10.5), "hazard_stripes", Vector3.ZERO, false)
	box(paint, "HazardDoorB", Vector3(1.2, 0.004, 1.8), Vector3(1.4, 0.003, -21.5), "hazard_stripes", Vector3.ZERO, false)
	box(paint, "HazardEnd", Vector3(4.0, 0.004, 1.0), Vector3(0, 0.003, -31.3), "hazard_stripes", Vector3.ZERO, false)
	# Ralos centrais
	for z in [-5.0, -17.0, -27.0]:
		box(paint, "Drain", Vector3(0.6, 0.006, 0.6), Vector3(0, 0.003, z), "grate_dark", Vector3.ZERO, false)
	# --- Painéis elétricos no corredor ---
	instance(d, PROPS_DIR + "electrical_panel.tscn", "ElectricalPanelA", Vector3(-2.0, 0, -4.0 + 1.0), 90)
	instance(d, PROPS_DIR + "electrical_panel.tscn", "ElectricalPanelB", Vector3(2.0, 0, -14.0), -90)
	# --- Elevador lacrado atrás do nascimento ---
	var elevator := instance(d, PROPS_DIR + "blast_door.tscn", "SealedElevator", Vector3(0, 0, 2.0), 180)
	elevator.scale = Vector3(0.95, 0.95, 1.0)
	make_sign(d, "SignElevator", "ELEVADOR DE CARGA\nFORA DE SERVIÇO", Vector3(0, 3.35, 1.98), 180, Vector2(1.6, 0.3), "sign_red", Color(0.95, 0.9, 0.85))
	# --- Portão do Setor C (fim do corredor) ---
	instance(d, PROPS_DIR + "blast_door.tscn", "SectorCGate", Vector3(0, 0, -31.95), 0)
	make_sign(d, "SignSectorC", "SETOR C — ACESSO RESTRITO", Vector3(0, 3.35, -31.98), 0, Vector2(2.4, 0.28), "sign_yellow", Color(0.05, 0.05, 0.05))
	var gate_inspect := Area3D.new()
	gate_inspect.set_script(load("res://scripts/interaction/inspectable.gd"))
	gate_inspect.position = Vector3(0, 1.4, -31.6)
	_add(d, gate_inspect, "SectorCInspect")
	gate_inspect.collision_layer = 1 << 2
	gate_inspect.collision_mask = 0
	gate_inspect.set(&"prompt_text", "examinar o portão")
	gate_inspect.set(&"message", "Portão do Setor C travado. O painel está sem energia.")
	gate_inspect.set(&"sound_path", "res://assets/audio/doors/locked_02.ogg")
	col_box(gate_inspect, Vector3(2.8, 2.8, 0.4), Vector3.ZERO)
	var gsnd := AudioStreamPlayer3D.new()
	gsnd.bus = &"SFX"
	_add(gate_inspect, gsnd, "InspectAudio")
	# --- Placas de orientação ---
	make_sign(d, "SignSector", "SETOR B-2  ·  NÍVEL -3", Vector3(-1.99, 2.4, -1.0), 90, Vector2(1.5, 0.25), "sign_white", Color(0.1, 0.1, 0.1))
	make_sign(d, "SignMaint", "MANUTENÇÃO", Vector3(-1.96, 2.68, -10.5), 90, Vector2(0.9, 0.2), "sign_yellow", Color(0.05, 0.05, 0.05))
	make_sign(d, "SignStorage", "DEPÓSITO B / SALA TÉCNICA", Vector3(1.96, 2.62, -21.5), -90, Vector2(1.6, 0.16), "sign_yellow", Color(0.05, 0.05, 0.05))
	make_sign(d, "SignExit", "← SAÍDA DE EMERGÊNCIA BLOQUEADA", Vector3(1.99, 2.3, -5.7), -90, Vector2(2.2, 0.22), "sign_red", Color(0.95, 0.9, 0.85))
	make_sign(d, "SignVoltage", "⚡ RISCO DE CHOQUE", Vector3(1.99, 1.9, -29.0), -90, Vector2(0.9, 0.22), "sign_yellow", Color(0.05, 0.05, 0.05))
	# Número da área pintado na parede
	label3d(d, "WallNumber", "B-2", Vector3(1.99, 1.4, -10.0), Vector3(0, -90, 0), 256, Color(0.55, 0.53, 0.45, 0.9), 0.004)
	# --- Objetos no corredor (encostados, sem bloquear a passagem) ---
	instance(d, PROPS_DIR + "warning_stand.tscn", "WarningStand", Vector3(-0.9, 0, -7.6), 25)
	instance(d, PROPS_DIR + "pallet.tscn", "PalletCorr", Vector3(1.35, 0, -25.5), 90)
	instance(d, PROPS_DIR + "crate_wood.tscn", "CrateCorr1", Vector3(1.35, 0.14, -25.3), 92)
	instance(d, PROPS_DIR + "crate_metal.tscn", "CrateCorr2", Vector3(1.35, 1.14, -25.4), 80)
	instance(d, PROPS_DIR + "barrel_rusty.tscn", "BarrelCorr1", Vector3(-1.4, 0, -26.9))
	instance(d, PROPS_DIR + "barrel_hazard.tscn", "BarrelCorr2", Vector3(-1.35, 0, -30.2))
	instance(d, PROPS_DIR + "barrel_blue.tscn", "BarrelCorr3", Vector3(-1.5, 0, -16.8))


func _droop_cable(parent: Node, a: Vector3, b: Vector3, sag: float, segments: int = 6) -> void:
	# Aproxima uma catenária com segmentos de cilindro (sem colisão).
	var prev := a
	for i in range(1, segments + 1):
		var t := float(i) / segments
		var p := a.lerp(b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		var mid := (prev + p) * 0.5
		var dir := p - prev
		var mi := MeshInstance3D.new()
		mi.mesh = _cyl_mesh(0.016, dir.length() + 0.01, M["rubber_black"], 6)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(parent, mi, "CableSeg")
		mi.position = mid
		# Alinha o eixo Y do cilindro com a direção do segmento.
		var y := dir.normalized()
		var x := y.cross(Vector3.UP if absf(y.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT).normalized()
		var z := x.cross(y).normalized()
		mi.basis = Basis(x, y, z)
		prev = p


func _build_maintenance_room(r: Node) -> void:
	var m := Node3D.new()
	_add(r, m, "MaintenanceRoom")
	# Porta funcional (vão em x = -2.15, z = -10.5)
	instance(m, "res://scenes/interactables/industrial_door.tscn", "DoorMaintenance", Vector3(-2.15, 0, -10.5), 90)
	instance(m, PROPS_DIR + "desk.tscn", "Desk", Vector3(-7.9, 0, -8.0), 180 - 90)
	instance(m, PROPS_DIR + "chair.tscn", "Chair", Vector3(-7.1, 0, -8.2), 70)
	for i in 4:
		instance(m, PROPS_DIR + "locker.tscn", "Locker%d" % i, Vector3(-4.0 - i * 0.52, 0, -13.7), 0)
	instance(m, PROPS_DIR + "shelf.tscn", "Shelf", Vector3(-8.65, 0, -12.0), 90)
	instance(m, PROPS_DIR + "crate_metal.tscn", "ShelfBox1", Vector3(-8.65, 0.83, -12.4), 95)
	instance(m, PROPS_DIR + "crate_metal.tscn", "ShelfBox2", Vector3(-8.65, 1.48, -11.6), 85)
	instance(m, PROPS_DIR + "crate_metal.tscn", "ShelfBox3", Vector3(-8.65, 0.14, -11.3), 90)
	instance(m, PROPS_DIR + "electrical_panel.tscn", "Panel", Vector3(-5.0, 0, -7.0), 180)
	instance(m, PROPS_DIR + "barrel_blue.tscn", "Barrel", Vector3(-8.5, 0, -13.5))
	# Quadro de avisos
	box(m, "Board", Vector3(1.2, 0.8, 0.03), Vector3(-6.5, 1.6, -7.0 - 0.015), "wood_crate", Vector3.ZERO, false)
	for i in 5:
		box(m, "Note", Vector3(0.2, 0.26, 0.005), Vector3(-6.9 + i * 0.2, 1.62 + (i % 2) * 0.1, -7.04), "sign_white", Vector3(0, 0, -6 + i * 3), false)
	make_sign(m, "Notice", "TURNO NOTURNO:\nNÃO DESCER\nAO SETOR C", Vector3(-6.2, 1.45, -7.03), 180, Vector2(0.42, 0.3), "sign_white", Color(0.5, 0.05, 0.05))
	# Cano vertical no canto
	cyl(m, "PipeCorner", 0.08, RA_H, Vector3(-8.85, RA_H / 2, -7.2), "metal_rusty", Vector3.ZERO, true, 12)


func _build_storage_room(r: Node) -> void:
	var s := Node3D.new()
	_add(r, s, "StorageRoom")
	instance(s, "res://scenes/interactables/industrial_door.tscn", "DoorStorage", Vector3(2.15, 0, -21.5), -90)
	# Disjuntor logo ao lado da porta, por dentro
	instance(s, PROPS_DIR + "breaker_panel.tscn", "BreakerPanel", Vector3(2.3, 0, -19.6), 90)
	# Canto técnico: piso de chapa, transformador, cabos no chão
	box(s, "PlateFloor", Vector3(3.6, 0.02, 4.0), Vector3(9.1, 0.01, -24.0), "metal_plate_floor")
	var plate_col := col_box(_col, Vector3(3.6, 0.02, 4.0), Vector3(9.1, 0.01, -24.0))
	plate_col.set_meta(&"surface", "metal") # passos em metal nesta área
	instance(s, PROPS_DIR + "transformer.tscn", "Transformer", Vector3(9.6, 0.02, -24.4), -90)
	box(s, "HazardTransformer", Vector3(2.4, 0.004, 0.25), Vector3(8.4, 0.025, -22.2), "hazard_stripes", Vector3.ZERO, false)
	for i in 3:
		cyl(s, "FloorCable", 0.03, 3.0, Vector3(7.6 + i * 0.12, 0.05, -24.2), "rubber_black", Vector3(90, 8 * i, 0), false, 6)
	cyl(s, "CableUp", 0.05, RB_H, Vector3(10.95, RB_H / 2, -25.9), "rubber_black", Vector3.ZERO, false, 8)
	# Prateleiras com caixas
	instance(s, PROPS_DIR + "shelf.tscn", "ShelfA", Vector3(5.0, 0, -17.35), 180)
	instance(s, PROPS_DIR + "shelf.tscn", "ShelfB", Vector3(7.3, 0, -17.35), 180)
	instance(s, PROPS_DIR + "shelf.tscn", "ShelfC", Vector3(5.2, 0, -21.5), 90)
	var shelf_boxes := [[4.4, 0.14, -17.35], [5.5, 0.83, -17.35], [6.8, 1.48, -17.35], [7.9, 0.14, -17.35], [5.2, 0.83, -20.9], [5.2, 1.48, -22.1]]
	for i in shelf_boxes.size():
		var b: Array = shelf_boxes[i]
		instance(s, PROPS_DIR + "crate_metal.tscn", "ShelfCrate%d" % i, Vector3(b[0], b[1], b[2]), 85 + i * 4)
	# Paletes e caixotes empilhados
	instance(s, PROPS_DIR + "pallet.tscn", "Pallet1", Vector3(9.8, 0, -18.4))
	instance(s, PROPS_DIR + "crate_wood.tscn", "Crate1", Vector3(9.55, 0.14, -18.4), 4)
	instance(s, PROPS_DIR + "crate_wood.tscn", "Crate2", Vector3(9.75, 1.14, -18.5), -7)
	instance(s, PROPS_DIR + "pallet.tscn", "Pallet2", Vector3(7.6, 0, -19.6), 90)
	instance(s, PROPS_DIR + "crate_wood.tscn", "Crate3", Vector3(7.6, 0.14, -19.6), 85)
	# Tambores (alguns perigosos) em grupo
	var barrels := [["barrel_hazard", 3.0, -25.6], ["barrel_hazard", 3.65, -25.65], ["barrel_blue", 3.3, -25.0], ["barrel_rusty", 4.3, -25.6], ["barrel_rusty", 6.0, -25.5]]
	for i in barrels.size():
		var b: Array = barrels[i]
		instance(s, PROPS_DIR + b[0] + ".tscn", "Barrel%d" % i, Vector3(b[1], 0, b[2]), i * 37)
	make_sign(s, "SignFlammable", "INFLAMÁVEL\nMANTER DISTÂNCIA", Vector3(3.6, 1.9, -25.98), 0, Vector2(0.8, 0.3), "sign_red", Color(0.95, 0.9, 0.85))
	# Tubulação descendo do teto até o transformador
	cyl(s, "PipeDown", 0.1, 1.4, Vector3(10.6, RB_H - 0.7, -22.6), "metal_rusty", Vector3.ZERO, true, 12)
	cyl(s, "PipeRun", 0.1, 8.5, Vector3(6.6, RB_H - 0.35, -22.6), "metal_rusty", Vector3(0, 0, 90), true, 12)


func _build_lights(r: Node) -> void:
	var l := Node3D.new()
	_add(r, l, "Lights")
	# Corredor: estados variados para criar zonas claras e escuras.
	var lamp_cfg := [
		# [z, powered, flicker]
		[-1.5, true, false],     # nascimento: referência segura
		[-7.0, true, true],      # falhando perto do escritório
		[-14.0, false, false],   # queimada: zona escura (lanterna!)
		[-18.5, true, false],
		[-26.5, true, true],     # falhando perto do fim
	]
	for i in lamp_cfg.size():
		var c: Array = lamp_cfg[i]
		var lamp := instance(l, PROPS_DIR + "ceiling_lamp.tscn", "CorridorLamp%d" % (i + 1), Vector3(0.45, CH, c[0]), 90)
		lamp.set(&"powered", c[1])
		lamp.set(&"flicker", c[2])
	# Escritório: luz quente e fraca
	var office := instance(l, PROPS_DIR + "ceiling_lamp_warm.tscn", "OfficeLamp", Vector3(-6.0, RA_H, -10.5), 0)
	office.set(&"flicker", true)
	office.set(&"stable_time_range", Vector2(5.0, 14.0))
	office.set(&"burst_count_range", Vector2i(1, 3))
	office.set(&"blackout_chance", 0.0)
	# Depósito: duas luminárias no circuito do disjuntor (começam apagadas)
	for i in 2:
		var lamp := instance(l, PROPS_DIR + "ceiling_lamp.tscn", "StorageLamp%d" % (i + 1), Vector3(5.2 + i * 3.6, RB_H, -21.5), 0)
		lamp.set(&"powered", false)
		lamp.add_to_group(&"circuit_storage", true)
	# Emergência: vermelho pulsante no fim e acima do elevador
	instance(l, PROPS_DIR + "emergency_light.tscn", "EmergencyEnd", Vector3(-1.4, 3.0, -31.98), 0)
	instance(l, PROPS_DIR + "emergency_light.tscn", "EmergencyEnd2", Vector3(1.4, 3.0, -31.98), 0)
	instance(l, PROPS_DIR + "emergency_light.tscn", "EmergencyElevator", Vector3(1.3, 3.1, 1.98), 180)
	instance(l, PROPS_DIR + "emergency_light.tscn", "EmergencyStorage", Vector3(10.98, 2.6, -20.0), -90)


func _build_wear(r: Node) -> void:
	var w := Node3D.new()
	_add(r, w, "Wear")
	# Manchas no chão (decal projeta para baixo por padrão)
	var floor_stains := [[0.3, -3.5, 2.0], [-0.8, -12.5, 2.6], [0.9, -20.0, 1.8], [-0.4, -29.5, 3.0], [-6.0, -12.0, 2.5], [7.5, -23.0, 3.0], [9.2, -19.0, 2.0]]
	for i in floor_stains.size():
		var s: Array = floor_stains[i]
		decal(w, "FloorStain%d" % i, "decal_grime.png" if i % 2 == 0 else "decal_oil.png", Vector3(s[0], 0.1, s[1]), Vector3(0, i * 47, 0), Vector3(s[2], 0.5, s[2]), 0.85)
	# Infiltrações escorrendo nas paredes (decal virado para a parede)
	var leaks := [[-1, -5.5], [-1, -18.0], [1, -9.5], [1, -27.5], [-1, -30.5]]
	for i in leaks.size():
		var lk: Array = leaks[i]
		var side: int = lk[0]
		wall_decal(w, "Leak%d" % i, "decal_leak.png", Vector3(1.9 * side, 2.0, lk[1]), Vector3(-side, 0, 0), Vector3(1.6, 0.5, 3.0), 0.9)
	# Poça d'água sob a infiltração (superfície "wet" para os passos)
	var puddle := decal(w, "Puddle", "decal_puddle_albedo.png", Vector3(-1.15, 0.1, -18.0), Vector3(0, 20, 0), Vector3(1.7, 0.4, 1.3), 1.0)
	puddle.texture_orm = _tex("decal_puddle_orm.png")
	var zone := Area3D.new()
	zone.set_script(load("res://scripts/environment/surface_zone.gd"))
	zone.position = Vector3(-1.15, 0.03, -18.0)
	_add(w, zone, "PuddleSurface")
	zone.collision_layer = 1 << 3
	zone.collision_mask = 0
	zone.set(&"surface", "wet")
	col_box(zone, Vector3(1.3, 0.06, 1.0), Vector3.ZERO, Vector3(0, 20, 0))
	# Sujeira na base das paredes do escritório e do depósito
	wall_decal(w, "GrimeOffice", "decal_grime.png", Vector3(-8.9, 0.6, -10.5), Vector3(1, 0, 0), Vector3(3.0, 0.5, 1.5), 0.8)
	wall_decal(w, "GrimeStorage", "decal_grime.png", Vector3(10.9, 0.8, -21.0), Vector3(-1, 0, 0), Vector3(3.5, 0.5, 2.0), 0.8)


func _build_gameplay_nodes(r: Node) -> void:
	var g := Node3D.new()
	_add(r, g, "Gameplay")
	var spawn := Marker3D.new()
	spawn.position = Vector3(0, 0.05, 0.6)
	_add(g, spawn, "PlayerSpawn")
	spawn.add_to_group(&"player_spawn", true)
	# Pontos extras para o multiplayer (até 6 jogadores). A ordem no grupo
	# define quem nasce onde: o host usa o primeiro.
	var extra := [Vector3(-0.75, 0.05, -0.5), Vector3(0.75, 0.05, -0.5),
		Vector3(-0.75, 0.05, -1.6), Vector3(0.75, 0.05, -1.6), Vector3(0, 0.05, -2.7)]
	for i in extra.size():
		var sp := Marker3D.new()
		sp.position = extra[i]
		_add(g, sp, "PlayerSpawn%d" % (i + 2))
		sp.add_to_group(&"player_spawn", true)
	# Rede de segurança abaixo do mapa
	var kz := Area3D.new()
	kz.set_script(load("res://scripts/environment/kill_zone.gd"))
	kz.position = Vector3(0, -15, -15)
	_add(g, kz, "KillZone")
	kz.add_to_group(&"kill_zone", true)
	col_box(kz, Vector3(80, 2, 80), Vector3.ZERO)
	# Fontes sonoras ambientes posicionais (ruído elétrico distante, gotejamento...)
	_looping_sound(g, "DistantMachinery", "res://assets/audio/ambience/electrical_hum.wav", Vector3(0, 2.5, -33.0), -12.0, 4.0, 30.0)
