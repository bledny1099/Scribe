======================================================================
  SCRIBE — HOW TO OPEN & FIX GATEKEEPER / КАК ОТКРЫТЬ И ОШИБКА GATEKEEPER
======================================================================

If macOS shows:
• "Scribe is damaged and can't be opened"
• "Cannot verify the developer"
• "Apple cannot check it for malicious software"

Если macOS показывает:
• «Файл Scribe поврежден, переместите его в Корзину»
• «Не удается проверить разработчика»
• «Apple не может проверить приложение на наличие вредоносного ПО»

----------------------------------------------------------------------
METHOD 1 / СПОСОБ 1 (Fastest via Terminal / Самый быстрый через Терминал):
----------------------------------------------------------------------
1. Drag Scribe into Applications folder.
   Перетащите Scribe в папку «Программы» (Applications).

2. Open Terminal (Spotlight -> Terminal) and paste:
   Откройте Терминал (Spotlight -> Терминал) и вставьте:

   xattr -cr /Applications/Scribe.app

3. Press Enter and launch Scribe!
   Нажмите Enter и запускайте Scribe!

----------------------------------------------------------------------
METHOD 2 / СПОСОБ 2 (Via System Settings / Через Системные настройки):
----------------------------------------------------------------------
1. Try opening Scribe once (macOS will show the warning).
   Попробуйте запустить Scribe (macOS покажет предупреждение).
2. Open System Settings -> Privacy & Security.
   Откройте Системные настройки -> Конфиденциальность и безопасность.
3. Scroll down to the "Security" section.
   Прокрутите вниз до раздела «Безопасность».
4. Click "Open Anyway" next to Scribe.
   Нажмите «Подтвердить вход» или «Все равно открыть» рядом со Scribe.
5. Confirm with your password/Touch ID -> click "Open".
   Подтвердите паролем или Touch ID -> нажмите «Открыть».

----------------------------------------------------------------------
WHY DOES THIS HAPPEN? / ПОЧЕМУ ЭТО ПРОИСХОДИТ?
----------------------------------------------------------------------
Scribe is a privacy-first, 100% on-device speech engine that runs
locally on Apple Silicon without sending any audio to external servers.
Because Scribe is distributed directly via GitHub rather than the Mac
App Store, macOS Gatekeeper quarantines the downloaded archive until
you confirm your trust using either of the methods above.

Scribe — приватная нейросетевая диктовка, которая работает полностью
локально на процессорах Apple Silicon и не отправляет аудио на серверы.
Поскольку приложение распространяется напрямую с GitHub, а не через
Mac App Store, macOS Gatekeeper автоматически помещает его в карантин
до первого подтверждения.
======================================================================
