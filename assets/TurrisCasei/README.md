# Turris Casei - casa medieval de quesos

Modelo low-poly estilizado generado proceduralmente en Blender 5.1.

| Dato | Valor |
|---|---|
| Triangulos | 5.442 (limite Roblox: 10.000 por MeshPart) |
| Vertices | 3.612 |
| Dimensiones | 38.36 x 46.30 x 25.00 studs |
| Materiales | 1 solo (albedo + normal) |
| Escala | 1 unidad Blender = 1 stud |
| Origen | centrado en XY, base en Z=0 |

## Archivos

- `TurrisCasei.fbx` - malla para importar (ejes ya convertidos a Y-up)
- `TurrisCasei_Albedo_1K.png` - color base **(usar esta, 1024px)**
- `TurrisCasei_Normal_1K.png` - normal map **(usar esta, 1024px)**
- `*_Albedo.png` / `*_Normal.png` - versiones 2048 por si suben el limite
- `TurrisCasei.blend` - proyecto editable
- `TurrisCasei.obj` / `.mtl` - formato alternativo
- `generate_turris.py` - script que genera todo, re-ejecutable

## Regenerar

```
"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background --python generate_turris.py -- "<carpeta_salida>"
```

Constantes utiles dentro del script: `STACK` (capas de queso), `STONE_T`/`TIMBER_T`/`ROOF_T`
(alturas del edificio), `PALETTE` (colores y tipo de detalle por material).
La torre se auto-ajusta para rematar SIEMPRE en Z=25.0 exacto.

## Importar a Roblox Studio

1. Asset Manager -> Bulk Import -> `TurrisCasei.fbx`
2. En el dialogo: escala 1.0, "Use scene origin" activado
3. Subir las dos texturas 1K por separado (Asset Manager -> Images)
4. En el MeshPart: `TextureID` = albedo
5. Insertar un `SurfaceAppearance` dentro del MeshPart:
   - `ColorMap` = albedo
   - `NormalMap` = normal
6. Colocar el MeshPart sobre `Baseturris`. Como el origen esta en la base,
   la posicion Y del modelo = (Y de Baseturris) + (grosor/2)
