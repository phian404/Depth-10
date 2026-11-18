Проверка проекта Depth-10.

1. Синтаксис конкретного файла:
   redot_code_intel(action="validate", path="res://<файл>")

2. Если MCP недоступен — консольная проверка:
   "E:\GameDevelopment\RedotEngine\redot.windows.editor.x86_64.llvm.console.exe" --headless --check-only --script "res://<файл>" --path "E:\GameDevelopment\RedotEngine\Projects\depth-10"

3. Загрузка проекта целиком:
   "E:\GameDevelopment\RedotEngine\redot.windows.editor.x86_64.llvm.console.exe" --headless --quit --path "E:\GameDevelopment\RedotEngine\Projects\depth-10"

Вывести только ошибки. Если ошибок нет — сказать «чисто», без пересказа логов.
