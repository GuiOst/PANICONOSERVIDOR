# Assets e licenças

## Criados para este projeto (sem licença de terceiros)
Todos foram gerados por código, do zero, especificamente para o Pânico no Servidor:

| Tipo | Arquivos | Gerador |
|---|---|---|
| Texturas (concreto, piso, metais, chapa xadrez, faixa de perigo, madeira, manchas, "cookie" da lanterna) | `assets/textures/*.png` | `tools/generators/make_textures.py` |
| Sons sintetizados (ambiente subterrâneo, zumbido elétrico, lâmpada, lanterna, disjuntor) | `assets/audio/ambience/*.wav`, `assets/audio/interactions/*.wav` | `tools/generators/make_audio.py` |
| Ícones da interface | `assets/textures/ui/*.svg`, `icon.svg` | feitos à mão |
| Materiais, porta, objetos e fase | `assets/materials`, `scenes/` | `tools/build_scenes.gd` |

Para regerar texturas e sons (opcional), use Python 3 com `numpy`, `scipy` e `pillow`:
```
python tools/generators/make_textures.py
python tools/generators/make_audio.py
```

## Gravações reais de terceiros (Etapa A: passos, porta e interface)
Passos (concreto, metal, poça), porta industrial e cliques de menu usam
**gravações reais** com licença CC0 ou CC BY 4.0. A lista completa, arquivo
por arquivo, com autor, licença e link original, está em
**`assets/audio/CREDITOS_AUDIO.md`**. As gravações CC BY exigem que os
créditos acompanhem o jogo distribuído.

Para baixar e processar de novo (precisa de git, ffmpeg, Python com numpy e scipy):
```
python tools/generators/process_recordings.py
```

## Outros recursos de terceiros
| Recurso | Licença | Origem |
|---|---|---|
| Fonte **DejaVu Sans Mono** (`assets/fonts/`) | Bitstream Vera / domínio público (livre para uso comercial) | <https://dejavu-fonts.github.io/>. Licença completa em `assets/fonts/LICENSE_DejaVu.txt` |
| Godot Engine | MIT | <https://godotengine.org/license> |
| **NodeTunnel** 1.1.1 beta (`addons/nodetunnel/`, extensão compilada) | MIT (`addons/nodetunnel/LICENSE`) | <https://github.com/curtjs/nodetunnel>. O relay público é gratuito e pede um token de aplicativo, criado em <https://www.nodetunnel.io> |

## Trocar sons por gravações reais (opcional)
1. Coloque o novo arquivo (`.wav` ou `.ogg`) **com o mesmo nome e no mesmo lugar** do antigo; ou
2. altere o caminho correspondente em `scripts/systems/audio_library.gd`.

Para sons em loop (`ambience/`), selecione o arquivo no Godot → aba **Importar** → *Loop Mode: Forward* → **Reimportar**.

Fontes gratuitas com licenças adequadas (confira a licença de CADA arquivo):
- **Freesound** (<https://freesound.org>): filtre por licença **CC0**. Busque "underground ambience", "fluorescent buzz", "metal door creak", "footsteps concrete".
- **Kenney** (<https://kenney.nl/assets>): pacotes de áudio e modelos **CC0**.
- **OpenGameArt** (<https://opengameart.org>): filtre por CC0 ou CC-BY (CC-BY exige dar crédito).
- **Sonniss GDC Game Audio Bundle** (<https://sonniss.com/gameaudiogdc>): pacotes anuais gratuitos, livres de royalties.
- Texturas: **ambientCG** (<https://ambientcg.com>) e **Poly Haven** (<https://polyhaven.com>), ambos **CC0**.

Se um som novo não existir ou estiver com nome errado, o jogo **não quebra**: apenas fica em silêncio.
