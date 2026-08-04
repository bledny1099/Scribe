import re

filepath = "/Users/aleksei/Documents/Scribe/Scribe/Utilities/Localization.swift"

with open(filepath, "r") as f:
    content = f.read()

missing = {
    "en": {
        "Auto Translate to Selected Language": "Auto Translate to Selected Language",
        "Small (Recommended)": "Small (Recommended)",
        "Great balance of high accuracy and speed (~460MB)": "Great balance of high accuracy and speed (~460MB)",
        "Large V3 Turbo": "Large V3 Turbo",
        "Highest quality for complex speech & terms (~950MB)": "Highest quality for complex speech & terms (~950MB)",
        "Base (Fastest)": "Base (Fastest)",
        "Lightweight and ultra fast, ideal for simple phrases (~140MB)": "Lightweight and ultra fast, ideal for simple phrases (~140MB)",
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!",
        "Buy Me a Coffee on Ko-fi": "Buy Me a Coffee on Ko-fi",
        "or Crypto": "or Crypto"
    },
    "ja": {
        "Auto Translate to Selected Language": "選択した言語に自動翻訳",
        "Small (Recommended)": "Small (推奨)",
        "Great balance of high accuracy and speed (~460MB)": "高精度と速度の素晴らしいバランス (~460MB)",
        "Large V3 Turbo": "Large V3 Turbo",
        "Highest quality for complex speech & terms (~950MB)": "複雑なスピーチや専門用語に最適な最高品質 (~950MB)",
        "Base (Fastest)": "Base (最速)",
        "Lightweight and ultra fast, ideal for simple phrases (~140MB)": "軽量で超高速、シンプルなフレーズに最適 (~140MB)",
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribeはユーザーからの寄付のみによって支えられている独立したプロジェクトです。もし役に立つと感じたら、開発のサポートをご検討ください。寄付は完全に任意です。ありがとうございます！",
        "Buy Me a Coffee on Ko-fi": "Ko-fiでコーヒーをご馳走する",
        "or Crypto": "または暗号資産"
    },
    "ru": {
        "Auto Translate to Selected Language": "Автоматический перевод на выбранный язык",
        "Small (Recommended)": "Small (Рекомендуется)",
        "Great balance of high accuracy and speed (~460MB)": "Отличный баланс высокой точности и скорости (~460MB)",
        "Large V3 Turbo": "Large V3 Turbo",
        "Highest quality for complex speech & terms (~950MB)": "Высочайшее качество для сложной речи и терминов (~950MB)",
        "Base (Fastest)": "Base (Самый быстрый)",
        "Lightweight and ultra fast, ideal for simple phrases (~140MB)": "Легкий и сверхбыстрый, идеально подходит для простых фраз (~140MB)",
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe — это независимый проект, поддерживаемый исключительно за счет пожертвований пользователей. Если он оказался вам полезен, вы можете поддержать его разработку. Пожертвования абсолютно добровольны. Спасибо!",
        "Buy Me a Coffee on Ko-fi": "Купить мне кофе на Ko-fi",
        "or Crypto": "или Крипта"
    },
    "es": {
        "Auto Translate to Selected Language": "Traducir automáticamente al idioma seleccionado",
        "Small (Recommended)": "Small (Recomendado)",
        "Great balance of high accuracy and speed (~460MB)": "Gran equilibrio entre alta precisión y velocidad (~460MB)",
        "Large V3 Turbo": "Large V3 Turbo",
        "Highest quality for complex speech & terms (~950MB)": "La más alta calidad para discursos y términos complejos (~950MB)",
        "Base (Fastest)": "Base (El más rápido)",
        "Lightweight and ultra fast, ideal for simple phrases (~140MB)": "Ligero y ultra rápido, ideal para frases simples (~140MB)",
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe es un proyecto independiente apoyado en su totalidad por donaciones de usuarios. Si te resulta útil, considera apoyar su desarrollo. Las donaciones son completamente opcionales. ¡Gracias!",
        "Buy Me a Coffee on Ko-fi": "Cómprame un café en Ko-fi",
        "or Crypto": "o Cripto"
    },
    "de": {
        "Auto Translate to Selected Language": "Automatisch in ausgewählte Sprache übersetzen",
        "Small (Recommended)": "Small (Empfohlen)",
        "Great balance of high accuracy and speed (~460MB)": "Tolles Gleichgewicht zwischen hoher Genauigkeit und Geschwindigkeit (~460MB)",
        "Large V3 Turbo": "Large V3 Turbo",
        "Highest quality for complex speech & terms (~950MB)": "Höchste Qualität für komplexe Sprache & Begriffe (~950MB)",
        "Base (Fastest)": "Base (Am schnellsten)",
        "Lightweight and ultra fast, ideal for simple phrases (~140MB)": "Leicht und ultraschnell, ideal für einfache Sätze (~140MB)",
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe ist ein unabhängiges Projekt, das ausschließlich durch Benutzerspenden unterstützt wird. Wenn Sie es nützlich finden, ziehen Sie in Betracht, seine Entwicklung zu unterstützen. Spenden sind völlig freiwillig. Vielen Dank!",
        "Buy Me a Coffee on Ko-fi": "Kauf mir einen Kaffee auf Ko-fi",
        "or Crypto": "oder Krypto"
    },
    "fr": {
        "Auto Translate to Selected Language": "Traduire automatiquement dans la langue sélectionnée",
        "Small (Recommended)": "Small (Recommandé)",
        "Great balance of high accuracy and speed (~460MB)": "Excellent équilibre entre haute précision et vitesse (~460MB)",
        "Large V3 Turbo": "Large V3 Turbo",
        "Highest quality for complex speech & terms (~950MB)": "Qualité optimale pour discours et termes complexes (~950MB)",
        "Base (Fastest)": "Base (Le plus rapide)",
        "Lightweight and ultra fast, ideal for simple phrases (~140MB)": "Léger et ultra rapide, idéal pour phrases simples (~140MB)",
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe est un projet indépendant entièrement soutenu par les dons des utilisateurs. Si vous le trouvez utile, pensez à soutenir son développement. Les dons sont totalement optionnels. Merci !",
        "Buy Me a Coffee on Ko-fi": "Offrez-moi un café sur Ko-fi",
        "or Crypto": "ou Crypto"
    },
    "it": {
        "Auto Translate to Selected Language": "Traduci automaticamente nella lingua selezionata",
        "Small (Recommended)": "Small (Consigliato)",
        "Great balance of high accuracy and speed (~460MB)": "Ottimo equilibrio tra elevata precisione e velocità (~460MB)",
        "Large V3 Turbo": "Large V3 Turbo",
        "Highest quality for complex speech & terms (~950MB)": "Massima qualità per discorsi e termini complessi (~950MB)",
        "Base (Fastest)": "Base (Il più veloce)",
        "Lightweight and ultra fast, ideal for simple phrases (~140MB)": "Leggero e ultra veloce, ideale per frasi semplici (~140MB)",
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe è un progetto indipendente supportato interamente dalle donazioni degli utenti. Se lo trovi utile, prendi in considerazione l'idea di supportarne lo sviluppo. Le donazioni sono completamente opzionali. Grazie!",
        "Buy Me a Coffee on Ko-fi": "Offrimi un caffè su Ko-fi",
        "or Crypto": "o Cripto"
    },
    "zh": {
        "Auto Translate to Selected Language": "自动翻译为所选语言",
        "Small (Recommended)": "Small (推荐)",
        "Great balance of high accuracy and speed (~460MB)": "高精度和速度的完美平衡 (~460MB)",
        "Large V3 Turbo": "Large V3 Turbo",
        "Highest quality for complex speech & terms (~950MB)": "复杂语音和术语的最高质量 (~950MB)",
        "Base (Fastest)": "Base (最快)",
        "Lightweight and ultra fast, ideal for simple phrases (~140MB)": "轻量超快，简单短语的理想选择 (~140MB)",
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe是一个完全由用户捐助支持的独立项目。如果您觉得它有用，请考虑支持它的开发。捐助完全是自愿的。谢谢您！",
        "Buy Me a Coffee on Ko-fi": "在Ko-fi上请我喝杯咖啡",
        "or Crypto": "或使用加密货币"
    },
    "pt": {
        "Auto Translate to Selected Language": "Traduzir automaticamente para o idioma selecionado",
        "Small (Recommended)": "Small (Recomendado)",
        "Great balance of high accuracy and speed (~460MB)": "Ótimo equilíbrio entre alta precisão e velocidade (~460MB)",
        "Large V3 Turbo": "Large V3 Turbo",
        "Highest quality for complex speech & terms (~950MB)": "A mais alta qualidade para fala e termos complexos (~950MB)",
        "Base (Fastest)": "Base (O mais rápido)",
        "Lightweight and ultra fast, ideal for simple phrases (~140MB)": "Leve e ultra rápido, ideal para frases simples (~140MB)",
        "Scribe is an independent project supported inteiramente por doações de usuários. Se você achar útil, considere apoiar seu desenvolvimento. As doações são completamente opcionais. Obrigado!": "O Scribe é um projeto independente apoiado inteiramente por doações de usuários. Se você achar útil, considere apoiar seu desenvolvimento. As doações são completamente opcionais. Obrigado!",
        "Buy Me a Coffee on Ko-fi": "Compre-me um café no Ko-fi",
        "or Crypto": "ou Cripto"
    },
    "tr": {
        "Auto Translate to Selected Language": "Seçilen dile otomatik çevir",
        "Small (Recommended)": "Small (Önerilen)",
        "Great balance of high accuracy and speed (~460MB)": "Yüksek doğruluk ve hız arasında mükemmel denge (~460MB)",
        "Large V3 Turbo": "Large V3 Turbo",
        "Highest quality for complex speech & terms (~950MB)": "Karmaşık konuşma ve terimler için en yüksek kalite (~950MB)",
        "Base (Fastest)": "Base (En Hızlı)",
        "Lightweight and ultra fast, ideal for simple phrases (~140MB)": "Hafif ve ultra hızlı, basit ifadeler için ideal (~140MB)",
        "Scribe is an independent project supported entirely by user donations. If you find it useful, consider supporting its development. Donations are completely optional. Thank you!": "Scribe, tamamen kullanıcı bağışlarıyla desteklenen bağımsız bir projedir. Yararlı buluyorsanız gelişimini desteklemeyi düşünebilirsiniz. Bağışlar tamamen isteğe bağlıdır. Teşekkürler!",
        "Buy Me a Coffee on Ko-fi": "Ko-fi'de bana bir kahve ısmarla",
        "or Crypto": "veya Kripto"
    },
    "uk": {
        "Auto Translate to Selected Language": "Автоматично перекладати обраною мовою",
        "Small (Recommended)": "Small (Рекомендовано)",
        "Great balance of high accuracy and speed (~460MB)": "Чудовий баланс високої точності та швидкості (~460MB)",
        "Large V3 Turbo": "Large V3 Turbo",
        "Highest quality for complex speech & terms (~950MB)": "Найвища якість для складної мови та термінів (~950MB)",
        "Base (Fastest)": "Base (Найшвидший)",
        "Lightweight and ultra fast, ideal for simple phrases (~140MB)": "Легкий та надшвидкий, ідеально підходить для простих фраз (~140MB)",
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

print("Injected ALL missing translations successfully!")
