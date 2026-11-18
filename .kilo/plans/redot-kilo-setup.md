# План: подготовка среды Depth-10 для Kilo Code

Версия 2. Заменяет исходный план целиком. Реализация — implementation-агентом, порядок обязательный.

---

## Цель

Не «опрятный проект», а **замкнутый цикл: агент пишет → сам проверяет → читает лог → коммитит**. Всё остальное вторично.

---

## Проверенный контекст

```
Движок:  E:\GameDevelopment\RedotEngine\
  редактор: redot.windows.editor.x86_64.llvm.exe
  консоль:  redot.windows.editor.x86_64.llvm.console.exe
Проект:  E:\GameDevelopment\RedotEngine\Projects\depth-10
project.godot: config_version=5, features 26.3 / Forward Plus / Redot, имя Depth-10
Скриптов нет. Язык — GDScript. .godot/ уже в .gitignore.
.kilo/kilo.jsonc: только $schema. AGENTS.md нет. .kilo/command/ нет.
.editorconfig: только charset=utf-8.
```

---

## Решения (зафиксированы, не обсуждаются при реализации)

1. **GDScript.** C# не используется.
2. **MCP в scope.** Это причина выбора Redot. Без него движок = обычный Godot, и форк не нужен.
3. **Проверка синтаксиса — `redot_code_intel:validate`.** Не «линтера нет», он есть внутри MCP.
4. **Абсолютные пути хардкодом.** Переменные окружения не вводим. Машина одна. При переносе правится в двух файлах: `mcp.json` и `.kilo/command/*`.
5. **Экспорт не делаем.** Шаблоны не установлены, команда была бы заглушкой.
6. **Один файл за ответ, ≤150 строк.** Это главное правило, а не пожелание.

---

## Затронутые файлы

| Файл | Действие |
|---|---|
| `.gitattributes` | создать |
| `.editorconfig` | заменить |
| `AGENTS.md` | создать |
| `mcp.json` | создать |
| `.kilo/kilo.jsonc` | дополнить, `$schema` сохранить |
| `.kilo/command/run.md` | создать |
| `.kilo/command/check.md` | создать |
| `scripts/smoke.gd` | создать, временный |

**Не трогать:** `.godot/`, `*.import`, `project.godot`, любые ресурсы.

---

## Шаг 1. `.gitattributes`

Нужен до `.editorconfig`, иначе git на Windows будет спорить с `eol=lf`.

```
* text=auto eol=lf

*.png binary
*.jpg binary
*.ogg binary
*.wav binary
*.glb binary
*.ttf binary
*.res binary
```

## Шаг 2. `.editorconfig`

```ini
root = true

[*]
charset = utf-8
indent_style = tab
indent_size = 4
end_of_line = lf
trim_trailing_whitespace = true
insert_final_newline = true

[*.md]
indent_style = space
indent_size = 2

[*.{json,jsonc,yml,yaml}]
indent_style = space
indent_size = 2

[*.tscn]
trim_trailing_whitespace = false
insert_final_newline = false
```

Последний блок обязателен: `.tscn` пишет движок, редакторские правила к нему применять нельзя.

## Шаг 3. `AGENTS.md`

```markdown
# Depth-10 — правила для агента

## Проект
Redot 26.3 (форк Godot 4), GDScript, рендерер Forward Plus.
Проект: E:\GameDevelopment\RedotEngine\Projects\depth-10
Движок: E:\GameDevelopment\RedotEngine\
  редактор: redot.windows.editor.x86_64.llvm.exe
  консоль:  redot.windows.editor.x86_64.llvm.console.exe

## Размер задачи
- Один ответ = один файл, максимум 150 строк.
- Не создавай несколько файлов без явной просьбы.
- Не рефактори то, о чём не просили.
- Правку давай точным фрагментом, не переписывай файл целиком.
- Больше одного файла за раз — только по прямой команде.

## Формат ответа
1. Путь файла (res://...)
2. Код целиком, без «// остальное без изменений»
3. Какой узел создать и куда прикрепить скрипт
4. Как проверить вручную: ровно 3 шага
5. Что может сломаться

## Проверка перед выдачей
- Синтаксис: redot_code_intel(action="validate")
- Логи после запуска: redot_project_config(action="output")
- Не выдавай код, не прошедший validate.

## Работа с файлами
- .tscn — только через redot_scene_action. Текстом не править.
- .gd — обычным текстовым редактированием.
- create_file_res — только для НОВЫХ файлов.
- .godot/ и *.import — не трогать никогда.
- project.godot — не менять без явной задачи.

## Запреты
- Не выдумывай API Redot/Godot. Не уверен — скажи прямо.
- Не пиши TODO вместо кода.
- Не добавляй аддоны, плагины, зависимости.
- Не добавляй HUD, оружие, NPC, лица персонажей.
- Не создавай autoload без явной просьбы.

## Стиль
GDScript: табы, UTF-8, LF.
snake_case — файлы и переменные. PascalCase — классы.
Комментарии на русском, кратко. Явные типы где поддерживаются.

## После запуска игры
Ждать 3–5 секунд перед вводом и скриншотами.

## Git
После каждого работающего состояния — коммит, одна строка описания.

## Канон сцены
Первое лицо. Ни одного лица в кадре, включая лицо героя.
HUD отсутствует. Один мотивированный источник света на помещение.
Внутренний рендер 640×360.
```

## Шаг 4. `mcp.json` в корне проекта

Консольный бинарник, не редакторский: MCP работает через stdio.

```json
{
  "mcpServers": {
    "redot": {
      "command": "E:\\GameDevelopment\\RedotEngine\\redot.windows.editor.x86_64.llvm.console.exe",
      "args": [
        "--headless",
        "--mcp-server",
        "--quiet",
        "--path",
        "E:\\GameDevelopment\\RedotEngine\\Projects\\depth-10"
      ],
      "enabled": true
    }
  }
}
```

Секретов нет, файл коммитится.

## Шаг 5. `.kilo/kilo.jsonc`

Дополнить, `$schema` сохранить.

```json
{
  "$schema": "https://app.kilo.ai/config.json",
  "permission": {
    "bash": {
      "E:\\GameDevelopment\\RedotEngine\\redot.windows.editor.x86_64.llvm.console.exe --headless *": "allow",
      "E:\\GameDevelopment\\RedotEngine\\redot.windows.editor.x86_64.llvm.exe --path *": "allow",
      "git status *": "allow",
      "git diff *": "allow",
      "git add *": "allow",
      "git commit *": "allow",
      "find *": "allow"
    }
  }
}
```

Точные пути вместо `redot*.exe` — wildcard в середине пути не проверен. Аргументы ограничены флагом, не открыты целиком.

Если матчер не сработает: агент один раз спросит разрешение, разрешить вручную и посмотреть, какой паттерн он предложит. Тогда записать его.

## Шаг 6. `.kilo/command/check.md`

```markdown
Проверка проекта Depth-10.

1. Синтаксис конкретного файла:
   redot_code_intel(action="validate", path="res://<файл>")

2. Если MCP недоступен — консольная проверка:
   "E:\GameDevelopment\RedotEngine\redot.windows.editor.x86_64.llvm.console.exe" --headless --check-only --script "res://<файл>" --path "E:\GameDevelopment\RedotEngine\Projects\depth-10"

3. Загрузка проекта целиком:
   "E:\GameDevelopment\RedotEngine\redot.windows.editor.x86_64.llvm.console.exe" --headless --quit --path "E:\GameDevelopment\RedotEngine\Projects\depth-10"

Вывести только ошибки. Если ошибок нет — сказать «чисто», без пересказа логов.
```

## Шаг 7. `.kilo/command/run.md`

```markdown
Запуск Depth-10.

В редакторе:
"E:\GameDevelopment\RedotEngine\redot.windows.editor.x86_64.llvm.exe" --path "E:\GameDevelopment\RedotEngine\Projects\depth-10"

Headless, 120 кадров:
"E:\GameDevelopment\RedotEngine\redot.windows.editor.x86_64.llvm.console.exe" --headless --quit-after 120 --path "E:\GameDevelopment\RedotEngine\Projects\depth-10"

Через MCP: redot_project_config(action="run"), затем output.
После run ждать 3–5 секунд перед вводом.
```

## Шаг 8. Проверка флагов и MCP

До смоук-теста, не после.

```
"E:\GameDevelopment\RedotEngine\redot.windows.editor.x86_64.llvm.console.exe" --help
```

Подтвердить наличие: `--headless`, `--quit`, `--quit-after`, `--check-only`, `--script`, `--mcp-server`.

Затем перезапустить VS Code и убедиться, что в Kilo видны пять контроллеров: `redot_scene_action`, `redot_resource_action`, `redot_code_intel`, `redot_project_config`, `redot_game_control`.

Если MCP не подключился — смоук-тест делать через консольные команды, но проблему зафиксировать, не замалчивать.

## Шаг 9. Смоук-тест связки

`scripts/smoke.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	print("depth-10 ok")
	quit()
```

Наследует `SceneTree`, поэтому запускается без сцены — проект пуст, сцен нет.

Порядок:
1. Агент создаёт файл.
2. `redot_code_intel:validate` — должно пройти.
3. Запуск:
   ```
   "...console.exe" --headless --script "res://scripts/smoke.gd" --path "E:\GameDevelopment\RedotEngine\Projects\depth-10"
   ```
4. В выводе есть `depth-10 ok`, код выхода 0.
5. `git add -A && git commit -m "env: smoke test passes"`

Это единственная проверка, которая подтверждает всё сразу: модель отвечает, агент видит проект, пишет файл, проверяет его и коммитит.

## Шаг 10. Проверка AGENTS.md

Задать агенту:

> Сколько строк максимум разрешает AGENTS.md и сколько файлов за один ответ?

Ожидается **150** и **один**. Любой другой ответ — файл не подхватился, разбираться до начала работы.

---

## Валидация

- [ ] `--help` подтвердил все шесть флагов
- [ ] пять MCP-контроллеров видны в Kilo
- [ ] `validate` проходит на `smoke.gd`
- [ ] headless-запуск напечатал `depth-10 ok`, exit 0
- [ ] агент ответил 150 / один на вопрос по AGENTS.md
- [ ] коммит создан
- [ ] `git status` чистый, `.godot/` не попал в индекс

---

## Вне scope

- Игровые сцены и скрипты, кроме `smoke.gd`
- LSP и расширение `godot-tools` (полезно, но отдельно)
- Экспорт и шаблоны экспорта
- Ассеты, звук, шейдеры
- Настройка провайдера и моделей — делается в глобальном конфиге вручную

---

## Что изменено относительно исходного плана

| Было | Стало | Причина |
|---|---|---|
| MCP вне scope | MCP в scope, шаг 4 и 8 | это причина выбора Redot |
| «Redot не имеет линтера» | `redot_code_intel:validate` | утверждение было неверным |
| AGENTS.md — гигиена | + контракт на размер и формат | без него агент вывалит пять файлов |
| glob `redot*.exe *` | точные пути, аргументы ограничены | матчер не проверен, права были слишком широкие |
| `eol=lf` без gitattributes | + `.gitattributes` | иначе git на Windows спорит с настройкой |
| export-заглушка с TODO | удалена | шаблонов нет, и TODO запрещён правилами |
| env `REDOT_BIN` | хардкод в двух файлах | переменные окружения не вводим |
| «ответы учитывают контекст» | вопрос с числами 150 / один | это проверяемо |
| `--check-only` в открытых вопросах | проверяется `--help` на шаге 8 | не нужно откладывать |
| смоук-теста нет | шаг 9 | единственное доказательство, что связка живая |