# Créditos de áudio — Pânico no Servidor

Todas as gravações abaixo são **reais** e foram verificadas uma a uma na
página de origem (outubro de 2026). Elas foram **processadas** para o jogo:
conversão para mono 48 kHz, filtro de graves, corte do silêncio inicial,
equalização de volume entre variações e, na porta, afinação mais grave e
mixagem em camadas. O processo está em
`tools/generators/process_recordings.py`, que pode ser executado de novo.

As licenças **CC0** não exigem crédito; ele aparece aqui por transparência.
As licenças **CC BY** exigem crédito ao autor: mantenha este arquivo (ou os
créditos equivalentes na tela de créditos do jogo) ao distribuir.

## Passos — `assets/audio/footsteps/`

| Arquivo(s) | Gravação original | Autor | Licença | Fonte |
|---|---|---|---|---|
| `concrete/walk_01–04` | "Footstep on Stone" 1–4 | sgossner (antigo usuário *samulis*) | CC0 1.0 | <https://freesound.org/s/197781/> (e 197780, 197779, 197778) |
| `concrete/walk_05–07` | "steps-on-stone01" | Erdie | CC BY 4.0 | <https://freesound.org/people/Erdie/sounds/41579/> |
| `concrete/run_01–10` | `footstep00–09` (RPG Audio) | Kenney | CC0 1.0 | <https://kenney.nl/assets/rpg-audio> |
| `metal/walk_01–05` | "Footstep_Metal" 1–5 | GiocoSound | CC0 1.0 | <https://freesound.org/s/421137/> (e 421136, 421134, 421133, 421132) |
| `metal/run_01–03` | "Metal Footsteps" | SoftDistortionFX (antigo usuário *mypantsfelldown*) | CC0 1.0 | <https://freesound.org/people/mypantsfelldown/sounds/398937/> |
| `metal/run_04–07` | GiocoSound (acima) + `impactPlate_light` (Impact Sounds) | GiocoSound + Kenney | CC0 1.0 | (acima) + <https://kenney.nl/assets/impact-sounds> |
| `wet/walk_01` | "water step" | nathanaelj83 | CC0 1.0 | <https://freesound.org/s/145242/> |
| `wet/walk_02–06` | série "Footsteps_Water_Light" (5 gravações) | duckduckpony | CC BY 4.0 | <https://freesound.org/s/204017/> (e 204035, 204034, 204033, 204032) |
| `wet/run_01–06` | as gravações de `wet/walk` + passada de bota (Kenney RPG Audio) | nathanaelj83, duckduckpony, Kenney | CC0 / CC BY 4.0 | (acima) |

## Porta industrial — `assets/audio/doors/`

| Arquivo(s) | Gravação original | Autor | Licença | Fonte |
|---|---|---|---|---|
| `unlatch_01`, `unlatch_03` | `metalLatch` (RPG Audio) | Kenney | CC0 1.0 | <https://kenney.nl/assets/rpg-audio> |
| `unlatch_02` | "Parking Garage - Metal Door - Open & Close" (trecho de abertura) | sndadv (antigo usuário *HazMattt*) | CC BY 4.0 | <https://freesound.org/people/HazMattt/sounds/187283/> |
| `creak_open_01–03`, `creak_close_01–03` | `creak1–3` (RPG Audio), afinados para baixo | Kenney | CC0 1.0 | <https://kenney.nl/assets/rpg-audio> |
| `stop_open_01–03` | `impactMetal_medium` (Impact Sounds) | Kenney | CC0 1.0 | <https://kenney.nl/assets/impact-sounds> |
| `slam_01`, `slam_03` | porta de aço (sndadv/HazMattt, acima) + `impactPlate_heavy` + `metalLatch` | sndadv; Kenney | CC BY 4.0 + CC0 | (acima) |
| `slam_02` | porta de cofre metálico + `impactPlate_heavy` + `metalLatch` | DoctorBoomstick; Kenney | CC BY 4.0 + CC0 | gravação própria do autor, publicada no pacote CC-Sounds: <https://github.com/Fris0uman/CDDA-Soundpacks> |
| `locked_01–02` | `metalLatch` + `metalClick` (RPG Audio) | Kenney | CC0 1.0 | <https://kenney.nl/assets/rpg-audio> |

## Interface — `assets/audio/ui/`

| Arquivo | Original | Autor | Licença | Fonte |
|---|---|---|---|---|
| `click.ogg` | `click3` (UI Audio) | Kenney | CC0 1.0 | <https://kenney.nl/assets/ui-audio> |
| `hover.ogg` | `rollover2` (UI Audio) | Kenney | CC0 1.0 | <https://kenney.nl/assets/ui-audio> |

## Criados para o projeto (síntese, sem licença de terceiros)
`ambience/*.wav` e `interactions/*.wav` (lanterna, disjuntor) — gerados por
`tools/generators/make_audio.py`. Serão substituídos por gravações reais na
etapa de polimento sonoro.

## De onde os arquivos foram obtidos
Os arquivos foram baixados de repositórios públicos que redistribuem essas
gravações com os créditos acima: Minetest/Luanti Game
(<https://github.com/luanti-org/minetest_game>), pacote CC-Sounds do
Cataclysm: DDA (<https://github.com/Fris0uman/CDDA-Soundpacks>) e cópias dos
pacotes CC0 da Kenney (<https://github.com/iwenzhou/kenney>,
<https://github.com/latent-spaces/brag>). As licenças foram conferidas nas
páginas originais do Freesound e da Kenney.
