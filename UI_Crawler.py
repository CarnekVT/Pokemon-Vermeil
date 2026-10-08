import os, re, json

# Rutas de búsqueda
scripts_path = 'Data/Scripts'
output_file = 'Plugins/[ZBOX] UI Editor/UI_Definition.json'

def find_constants():
    # Estructura base
    definition = {"pc_storage": {"label": "PC Storage", "elements": []}}
    
    # Regex para capturar: CONST = valor
    # Busca constantes que contengan X, Y, WIDTH, HEIGHT (comunes en UI)
    const_pattern = re.compile(r'^\s*([A-Z0-9_]+)\s*=\s*(\d+)')
    
    # Escanear scripts
    for root, _, files in os.walk(scripts_path):
        for file in files:
            if file.endswith('.rb'):
                with open(os.path.join(root, file), 'r', encoding='latin-1', errors='ignore') as f:
                    content = f.read()
                    # Detectar clase
                    class_match = re.search(r'class\s+(\w+)', content)
                    if not class_match: continue
                    klass = class_match.group(1)

                    for const, val in const_pattern.findall(content):
                        # Filtrar solo constantes que suenen a UI
                        if any(x in const for x in ['X', 'Y', 'WIDTH', 'HEIGHT', 'POS']):
                            definition["pc_storage"]["elements"].append({
                                "klass": klass,
                                "const": const,
                                "label": f"{klass}::{const}"
                            })
    return definition

# Ejecutar y guardar
data = find_constants()
os.makedirs(os.path.dirname(output_file), exist_ok=True)
with open(output_file, 'w') as f:
    json.dump(data, f, indent=2)

print(f"✅ Definición generada en: {output_file}")
