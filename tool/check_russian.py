"""Validate source catalog parity without invoking a translation service."""
import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[1]
en = json.loads((root / 'lib/l10n/app_en.arb').read_text(encoding='utf-8-sig'))
ru = json.loads((root / 'lib/l10n/app_ru.arb').read_text(encoding='utf-8-sig'))
errors = []
keys = [k for k in en if not k.startswith('@')]
if set(en) != set(ru):
    errors.append('English and Russian catalog keys differ')
if ru.get('@@locale') != 'ru':
    errors.append('Russian locale identifier missing')
for k in keys:
    value = ru.get(k)
    if not isinstance(value, str) or not value.strip():
        errors.append(f'{k}: empty or non-string value')
        continue
    declared = set(en.get('@' + k, {}).get('placeholders', {}))
    variables = lambda s: set(re.findall(r'\{([a-zA-Z_]\w*)\s*[,}]', s)) & declared
    if variables(en[k]) != variables(value):
        errors.append(f'{k}: variable mismatch {variables(en[k])} / {variables(value)}')
    if '\ufffd' in value:
        errors.append(f'{k}: Unicode replacement character')
    if any(c in value for c in ['Рџ', 'РёР', 'СЃС']):
        errors.append(f'{k}: possible mojibake')
    if value.count('{') != value.count('}'):
        errors.append(f'{k}: unbalanced ICU braces')
    meta = '@' + k
    if meta in en and ru.get(meta) != en[meta]:
        errors.append(f'{k}: source metadata was changed')

untranslated = {k: ru[k] for k in keys if en[k] == ru[k]}
print(f'Messages: {len(keys)}')
print(f'Russian text: {sum(bool(re.search("[А-Яа-яЁё]", ru.get(k, ""))) for k in keys)}')
print(f'Unchanged strings (review brands/units explicitly): {len(untranslated)}')
out = root / 'build/ru-review'
out.mkdir(parents=True, exist_ok=True)
(out / 'unchanged.json').write_text(json.dumps(untranslated, ensure_ascii=False, indent=2), encoding='utf-8')
for error in errors:
    print('ERROR:', error)
print(f'Catalog errors: {len(errors)}')
sys.exit(1 if errors else 0)
