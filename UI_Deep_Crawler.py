import os, re, json

scripts_path = 'Data/Scripts'
output_file = 'Plugins/[ZBOX] UI Editor/UI_Definition_Full.json'

def find_ui_elements():
    definition = {}
    # Captura: "NOMBRE_CONST = 123"
    const_pattern = re.compile(r'^\s*([A-Z0-9_]+)\s*=\s*(\d+)')
    
    for root, _, files in os.walk(scripts_path):
        for file in files:
            if file.endswith('.rb'):
                # Leer usando 'latin-1' para evitar errores de codificación en scripts
                with open(os.path.join(root, file), 'r', encoding='latin-1', errors='ignore') as f:
                    content = f.read()
                    # Detectar clase
                    class_match = re.search(r'class\s+(\w+)', content)
                    if not class_match: continue
                    klass = class_match.group(1)
                    
                    # Buscar constantes que parecen de UI
                    for const, val in const_pattern.findall(content):
                        if any(x in const for x in ['X', 'Y', 'WIDTH', 'HEIGHT', 'POS']):
                            if klass not in definition: definition[klass] = {"elements": []}
                            definition[klass]["elements"].append({
                                "klass": klass,
                                "const": const,
                                "label": f"{klass}::{const}"
                            })
    return definition

data = find_ui_elements()
# Asegurar carpeta de destino
os.makedirs(os.path.dirname(output_file), exist_ok=True)
with open(output_file, 'w') as f:
    json.dump(data, f, indent=2)
print(f"✅ Definición total generada: {output_file}")
