import re
import sys

filepath = "/Users/aleksei/Documents/Scribe/Scribe/Utilities/Localization.swift"

with open(filepath, "r") as f:
    content = f.read()

# Missing translations for each language
# We only append these to dictionaries if they don't already exist.
missing = {
    "en": {
        "Overlay Size": "Overlay Size",
        "Live Floating Preview": "Live Floating Preview",
        "Statistics": "Statistics",
        "Today": "Today",
        "This Week": "This Week",
        "All Time": "All Time",
        "Words Spoken": "Words Spoken",
        "Characters": "Characters",
        "Time Dictated": "Time Dictated",
        "Sessions": "Sessions",
        "Launch at Login": "Launch at Login",
        "Sound Feedback": "Sound Feedback",
        "Permissions": "Permissions",
        "Microphone": "Microphone",
        "Accessibility": "Accessibility",
        "Granted": "Granted",
        "Grant Access": "Grant Access",
        "Support Scribe": "Support Scribe"
    },
    "ja": {
        "Overlay Size": "オーバーレイサイズ",
        "Live Floating Preview": "ライブフローティングプレビュー",
        "Statistics": "統計",
        "Today": "今日",
        "This Week": "今週",
        "All Time": "全期間",
        "Words Spoken": "話した単語数",
        "Characters": "文字数",
        "Time Dictated": "音声入力時間",
        "Sessions": "セッション",
        "Launch at Login": "ログイン時に起動",
        "Sound Feedback": "サウンドフィードバック",
        "Permissions": "権限",
        "Microphone": "マイク",
        "Accessibility": "アクセシビリティ",
        "Granted": "許可済み",
        "Grant Access": "アクセスを許可",
        "Support Scribe": "Scribeを支援"
    },
    "ru": {
        "Overlay Size": "Размер оверлея",
        "Live Floating Preview": "Плавающее превью",
        "Statistics": "Статистика",
        "Today": "Сегодня",
        "This Week": "На этой неделе",
        "All Time": "За все время",
        "Words Spoken": "Слов произнесено",
        "Characters": "Символов",
        "Time Dictated": "Время диктовки",
        "Sessions": "Сессии",
        "Launch at Login": "Запускать при входе",
        "Sound Feedback": "Звуковой отклик",
        "Permissions": "Разрешения",
        "Microphone": "Микрофон",
        "Accessibility": "Универсальный доступ",
        "Granted": "Предоставлено",
        "Grant Access": "Предоставить доступ",
        "Support Scribe": "Поддержать Scribe"
    },
    "es": {
        "Overlay Size": "Tamaño del overlay",
        "Live Floating Preview": "Vista previa flotante",
        "Statistics": "Estadísticas",
        "Today": "Hoy",
        "This Week": "Esta semana",
        "All Time": "Todo el tiempo",
        "Words Spoken": "Palabras",
        "Characters": "Caracteres",
        "Time Dictated": "Tiempo",
        "Sessions": "Sesiones",
        "Launch at Login": "Abrir al inicio",
        "Sound Feedback": "Retroalimentación",
        "Permissions": "Permisos",
        "Microphone": "Micrófono",
        "Accessibility": "Accesibilidad",
        "Granted": "Otorgado",
        "Grant Access": "Dar acceso",
        "Support Scribe": "Apoyar a Scribe"
    },
    "de": {
        "Overlay Size": "Overlay-Größe",
        "Live Floating Preview": "Live-Vorschau",
        "Statistics": "Statistiken",
        "Today": "Heute",
        "This Week": "Diese Woche",
        "All Time": "Gesamte Zeit",
        "Words Spoken": "Wörter",
        "Characters": "Zeichen",
        "Time Dictated": "Zeit",
        "Sessions": "Sitzungen",
        "Launch at Login": "Beim Anmelden starten",
        "Sound Feedback": "Sound-Feedback",
        "Permissions": "Berechtigungen",
        "Microphone": "Mikrofon",
        "Accessibility": "Bedienungshilfen",
        "Granted": "Gewährt",
        "Grant Access": "Zugriff gewähren",
        "Support Scribe": "Scribe unterstützen"
    },
    "fr": {
        "Overlay Size": "Taille de la superposition",
        "Live Floating Preview": "Aperçu flottant",
        "Statistics": "Statistiques",
        "Today": "Aujourd'hui",
        "This Week": "Cette semaine",
        "All Time": "Depuis toujours",
        "Words Spoken": "Mots",
        "Characters": "Caractères",
        "Time Dictated": "Temps",
        "Sessions": "Sessions",
        "Launch at Login": "Ouvrir au démarrage",
        "Sound Feedback": "Retour sonore",
        "Permissions": "Autorisations",
        "Microphone": "Microphone",
        "Accessibility": "Accessibilité",
        "Granted": "Accordé",
        "Grant Access": "Accorder l'accès",
        "Support Scribe": "Soutenir Scribe"
    },
    "it": {
        "Overlay Size": "Dimensione overlay",
        "Live Floating Preview": "Anteprima fluttuante",
        "Statistics": "Statistiche",
        "Today": "Oggi",
        "This Week": "Questa settimana",
        "All Time": "Tutto il tempo",
        "Words Spoken": "Parole",
        "Characters": "Caratteri",
        "Time Dictated": "Tempo",
        "Sessions": "Sessioni",
        "Launch at Login": "Apri al login",
        "Sound Feedback": "Feedback sonoro",
        "Permissions": "Permessi",
        "Microphone": "Microfono",
        "Accessibility": "Accessibilità",
        "Granted": "Concesso",
        "Grant Access": "Concedi l'accesso",
        "Support Scribe": "Supporta Scribe"
    },
    "zh": {
        "Overlay Size": "覆盖层大小",
        "Live Floating Preview": "实时悬浮预览",
        "Statistics": "统计",
        "Today": "今天",
        "This Week": "本周",
        "All Time": "所有时间",
        "Words Spoken": "字数",
        "Characters": "字符数",
        "Time Dictated": "听写时间",
        "Sessions": "会话",
        "Launch at Login": "登录时启动",
        "Sound Feedback": "声音反馈",
        "Permissions": "权限",
        "Microphone": "麦克风",
        "Accessibility": "辅助功能",
        "Granted": "已授权",
        "Grant Access": "授权",
        "Support Scribe": "支持 Scribe"
    },
    "pt": {
        "Overlay Size": "Tamanho do overlay",
        "Live Floating Preview": "Pré-visualização",
        "Statistics": "Estatísticas",
        "Today": "Hoje",
        "This Week": "Esta semana",
        "All Time": "Todo o tempo",
        "Words Spoken": "Palavras",
        "Characters": "Caracteres",
        "Time Dictated": "Tempo",
        "Sessions": "Sessões",
        "Launch at Login": "Iniciar no login",
        "Sound Feedback": "Feedback sonoro",
        "Permissions": "Permissões",
        "Microphone": "Microfone",
        "Accessibility": "Acessibilidade",
        "Granted": "Concedido",
        "Grant Access": "Conceder acesso",
        "Support Scribe": "Apoiar o Scribe"
    },
    "tr": {
        "Overlay Size": "Yer paylaşımı boyutu",
        "Live Floating Preview": "Canlı önizleme",
        "Statistics": "İstatistikler",
        "Today": "Bugün",
        "This Week": "Bu hafta",
        "All Time": "Tüm zamanlar",
        "Words Spoken": "Kelimeler",
        "Characters": "Karakterler",
        "Time Dictated": "Süre",
        "Sessions": "Oturumlar",
        "Launch at Login": "Başlangıçta aç",
        "Sound Feedback": "Sesli geri bildirim",
        "Permissions": "İzinler",
        "Microphone": "Mikrofon",
        "Accessibility": "Erişilebilirlik",
        "Granted": "Verildi",
        "Grant Access": "İzin ver",
        "Support Scribe": "Scribe'ı destekle"
    },
    "uk": {
        "Overlay Size": "Розмір оверлею",
        "Live Floating Preview": "Плаваюче прев'ю",
        "Statistics": "Статистика",
        "Today": "Сьогодні",
        "This Week": "Цього тижня",
        "All Time": "За весь час",
        "Words Spoken": "Слів",
        "Characters": "Символів",
        "Time Dictated": "Час диктування",
        "Sessions": "Сесії",
        "Launch at Login": "Запускати при вході",
        "Sound Feedback": "Звуковий відгук",
        "Permissions": "Дозволи",
        "Microphone": "Мікрофон",
        "Accessibility": "Доступність",
        "Granted": "Надано",
        "Grant Access": "Надати доступ",
        "Support Scribe": "Підтримати Scribe"
    }
}

for lang, words in missing.items():
    # Find the dictionary for `lang`: e.g. `"ja": [`
    start_pattern = f'"{lang}": ['
    start_idx = content.find(start_pattern)
    if start_idx == -1:
        continue
    
    # Find the end of this dictionary (next `],`) or end of object
    end_idx = content.find("],", start_idx)
    if end_idx == -1:
        end_idx = content.find("]", start_idx)
    
    dict_content = content[start_idx:end_idx]
    
    lines_to_add = []
    for en_key, trans_val in words.items():
        # check if it already exists
        if f'"{en_key}":' not in dict_content:
            lines_to_add.append(f'            "{en_key}": "{trans_val}"')
            
    if lines_to_add:
        # insert before the closing bracket of this dict
        # Wait, need to handle commas. The last item in dict_content might not have a comma.
        # It's easier to find the last string definition and append a comma if needed.
        last_item_idx = dict_content.rfind('"')
        
        # let's just replace the closing bracket using regex 
        # But we only have `dict_content` which is the substring
        
        new_dict_content = dict_content.rstrip()
        
        # Check if the last real character is not a comma
        # Wait, if we just do:
        #            "Done ✓": "完成 ✓"
        # we need to add a comma to the last line.
        
        lines = dict_content.split('\n')
        # find the last non-empty line
        for i in range(len(lines)-1, -1, -1):
            if lines[i].strip():
                if not lines[i].strip().endswith(','):
                    lines[i] = lines[i] + ','
                break
                
        # Append new lines
        lines.extend(lines_to_add)
        
        # Join back, make sure the last line doesn't have a trailing comma
        lines[-1] = lines[-1].rstrip(',')
        
        new_dict_content = '\n'.join(lines) + '\n        '
        
        content = content[:start_idx] + new_dict_content + content[end_idx:]

with open(filepath, 'w') as f:
    f.write(content)

print("Injected translations successfully!")
