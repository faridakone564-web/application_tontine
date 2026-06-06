from pathlib import Path

path = Path('lib/screens/register_screen.dart')
text = path.read_text(encoding='utf-8')
old = "      if (!RegExp(r'^[0-9]{8}$').hasMatch(phone)) {\n        setState(() => _stepError = 'Téléphone invalide (8 chiffres)');\n        return false;\n      }\n"
new = "      final normalizedPhone = phone.replaceAll(RegExp(r'\\D'), '');\n      if (!RegExp(r'^\\d{8,15}$').hasMatch(normalizedPhone)) {\n        setState(() => _stepError = 'Téléphone invalide (8-15 chiffres)');\n        return false;\n      }\n"
if old not in text:
    raise SystemExit('old phone validation block not found')
text = text.replace(old, new)
old2 = "      if (!RegExp(r'^\\d{8,15}').hasMatch(normalizedUrgence)) {\n        setState(() => _stepError = 'Numéro d\'urgence invalide (8-15 chiffres)');\n        return false;\n      }\n"
new2 = "      if (!RegExp(r'^\\d{8,15}$').hasMatch(normalizedUrgence)) {\n        setState(() => _stepError = 'Numéro d\'urgence invalide (8-15 chiffres)');\n        return false;\n      }\n"
if old2 not in text:
    raise SystemExit('old urgence validation block not found')
text = text.replace(old2, new2)
path.write_text(text, encoding='utf-8')
print('patched')
