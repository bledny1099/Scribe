import re

filepath = "/Users/aleksei/Documents/Scribe/Scribe/Utilities/Localization.swift"

with open(filepath, "r") as f:
    content = f.read()

missing = {
    "en": {
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!",
        "Buy Me a Coffee on Ko-fi": "Buy Me a Coffee on Ko-fi",
        "or Crypto": "or Crypto"
    },
    "ja": {
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribeはユーザーからの寄付のみによって支えられている独立したプロジェクトです。もし役に立つと感じたら、開発のサポートをご検討ください。寄付は完全に任意です。ありがとうございます！",
        "Buy Me a Coffee on Ko-fi": "Ko-fiでコーヒーをご馳走する",
        "or Crypto": "または暗号資産"
    },
    "ru": {
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe — это независимый проект, поддерживаемый исключительно за счет пожертвований пользователей. Если он оказался вам полезен, вы можете поддержать его разработку. Пожертвования абсолютно добровольны. Спасибо!",
        "Buy Me a Coffee on Ko-fi": "Купить мне кофе на Ko-fi",
        "or Crypto": "или Крипта"
    },
    "es": {
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe es un proyecto independiente apoyado en su totalidad por donaciones de usuarios. Si te resulta útil, considera apoyar su desarrollo. Las donaciones son completamente opcionales. ¡Gracias!",
        "Buy Me a Coffee on Ko-fi": "Cómprame un café en Ko-fi",
        "or Crypto": "o Cripto"
    },
    "de": {
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe ist ein unabhängiges Projekt, das ausschließlich durch Benutzerspenden unterstützt wird. Wenn Sie es nützlich finden, ziehen Sie in Betracht, seine Entwicklung zu unterstützen. Spenden sind völlig freiwillig. Vielen Dank!",
        "Buy Me a Coffee on Ko-fi": "Kauf mir einen Kaffee auf Ko-fi",
        "or Crypto": "oder Krypto"
    },
    "fr": {
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe est un projet indépendant entièrement soutenu par les dons des utilisateurs. Si vous le trouvez utile, pensez à soutenir son développement. Les dons sont totalement optionnels. Merci !",
        "Buy Me a Coffee on Ko-fi": "Offrez-moi un café sur Ko-fi",
        "or Crypto": "ou Crypto"
    },
    "it": {
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe è un progetto indipendente supportato interamente dalle donazioni degli utenti. Se lo trovi utile, prendi in considerazione l'idea di supportarne lo sviluppo. Le donazioni sono completamente opzionali. Grazie!",
        "Buy Me a Coffee on Ko-fi": "Offrimi un caffè su Ko-fi",
        "or Crypto": "o Cripto"
    },
    "zh": {
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe是一个完全由用户捐助支持的独立项目。如果您觉得它有用，请考虑支持它的开发。捐助完全是自愿的。谢谢您！",
        "Buy Me a Coffee on Ko-fi": "在Ko-fi上请我喝杯咖啡",
        "or Crypto": "或使用加密货币"
    },
    "pt": {
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "O Scribe é um projeto independente apoiado inteiramente por doações de usuários. Se você achar útil, considere apoiar seu desenvolvimento. As doações são completamente opcionais. Obrigado!",
        "Buy Me a Coffee on Ko-fi": "Compre-me um café no Ko-fi",
        "or Crypto": "ou Cripto"
    },
    "tr": {
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe, tamamen kullanıcı bağışlarıyla desteklenen bağımsız bir projedir. Yararlı buluyorsanız gelişimini desteklemeyi düşünebilirsiniz. Bağışlar tamamen isteğe bağlıdır. Teşekkürler!",
        "Buy Me a Coffee on Ko-fi": "Ko-fi'de bana bir kahve ısmarla",
        "or Crypto": "veya Kripto"
    },
    "uk": {
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe — це незалежний проєкт, який повністю підтримується за рахунок пожертв користувачів. Якщо ви вважаєте його корисним, ви можете підтримати його розробку. Пожертви абсолютно добровільні. Дякуємо!",
        "Buy Me a Coffee on Ko-fi": "Придбати мені каву на Ko-fi",
        "or Crypto": "або Крипта"
    }
}

for lang, words in missing.items():
    start_pattern = f'"{lang}": ['
    start_idx = content.find(start_pattern)
    if start_idx == -1:
        continue
    
    end_idx = content.find("],", start_idx)
    if end_idx == -1:
        end_idx = content.find("]", start_idx)
    
    dict_content = content[start_idx:end_idx]
    
    lines_to_add = []
    for en_key, trans_val in words.items():
        if f'"{en_key}":' not in dict_content:
            lines_to_add.append(f'            "{en_key}": "{trans_val}"')
            
    if lines_to_add:
        lines = dict_content.split('\n')
        for i in range(len(lines)-1, -1, -1):
            if lines[i].strip():
                if not lines[i].strip().endswith(','):
                    lines[i] = lines[i] + ','
                break
                
        lines.extend(lines_to_add)
        lines[-1] = lines[-1].rstrip(',')
        
        new_dict_content = '\n'.join(lines) + '\n        '
        content = content[:start_idx] + new_dict_content + content[end_idx:]

with open(filepath, 'w') as f:
    f.write(content)

print("Injected translations for modal successfully!")
