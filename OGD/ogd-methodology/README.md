---
layout: default
title: "OGD Skill — установка"
parent: OGD (Методология)
nav_order: 90
---

# OGD Methodology Skill

Скилл для AI-агентов (Claude Code, Cursor, Cline, OpenCode, GitHub Copilot и других, поддерживающих стандарт Agent Skills). Превращает методологию OGD в рабочий инструмент анализа и проектирования игр.

## Установка

```bash
curl -sSL https://raw.githubusercontent.com/dim-s/indie-gamedev-knowledge-base/v0.9.5-beta/OGD/ogd-methodology/install.sh | bash
```

Скрипт склонирует репозиторий в `~/.local/share/indie-gamedev-knowledge-base`, найдёт установленный у тебя инструмент и поставит скилл туда через симлинк. Поддерживает macOS и Linux, нужны `bash` и `git`. Для Windows — см. ниже.

## Выбор инструмента

По умолчанию скрипт сам определяет, куда ставить. Если хочется явно — флаг `--target`:

| Инструмент | Имя для `--target` |
|------------|---------------------|
| Claude Code | `claude` / `claude-project` |
| Cursor | `cursor` / `cursor-project` |
| Cline | `cline` / `cline-project` |
| OpenCode | `opencode` / `opencode-project` |
| GitHub Copilot | `copilot` / `copilot-project` |

После установки через `curl` скрипт лежит здесь:

```bash
~/.local/share/indie-gamedev-knowledge-base/OGD/ogd-methodology/install.sh
```

Примеры команд (можно копировать целиком):

```bash
~/.local/share/indie-gamedev-knowledge-base/OGD/ogd-methodology/install.sh --target cursor
~/.local/share/indie-gamedev-knowledge-base/OGD/ogd-methodology/install.sh --target claude-project
~/.local/share/indie-gamedev-knowledge-base/OGD/ogd-methodology/install.sh --target /custom/path
~/.local/share/indie-gamedev-knowledge-base/OGD/ogd-methodology/install.sh --check
~/.local/share/indie-gamedev-knowledge-base/OGD/ogd-methodology/install.sh --help
```

Если клонировал репозиторий вручную, изнутри папки скилла достаточно `./install.sh --target ...`.

Без `--target` скрипт находит все уже установленные копии и обновляет их одновременно. Если ничего не установлено — ставит в первый из обнаруженных инструментов.

Альтернатива — гонять всё через `curl` без локального файла:

```bash
curl -sSL https://raw.githubusercontent.com/dim-s/indie-gamedev-knowledge-base/v0.9.5-beta/OGD/ogd-methodology/install.sh | bash -s -- --target cursor
curl -sSL https://raw.githubusercontent.com/dim-s/indie-gamedev-knowledge-base/v0.9.5-beta/OGD/ogd-methodology/install.sh | bash -s -- --check
```

Команда длинная, но не требует знать путь к локальному файлу.

## Обновление

Запусти ту же команду установки ещё раз — скрипт сделает `git pull` и покажет переход версий (например, `updated v0.9.4 → v0.9.5`). Или вручную:

```bash
cd ~/.local/share/indie-gamedev-knowledge-base && git pull
```

Симлинк автоматически указывает на свежую версию.

## Удаление

```bash
~/.local/share/indie-gamedev-knowledge-base/OGD/ogd-methodology/install.sh --check
rm <путь-из-вывода>
```

Удаляется только симлинк. Сам репозиторий с источниками остаётся на месте.

## Windows

Скрипт работает только на macOS и Linux. Под Windows есть три варианта:

**WSL (рекомендуется).** В терминале Ubuntu запусти ту же команду, что и для macOS — скилл встанет в `~/.claude/skills/` внутри WSL-окружения.

**Git Bash.** Работает, но симлинки требуют либо прав администратора, либо включённого Developer Mode в Windows.

**PowerShell, вручную.** Самый надёжный путь для нативного Windows — junction вместо симлинка:

```powershell
git clone https://github.com/dim-s/indie-gamedev-knowledge-base.git $env:USERPROFILE\code\indie-gamedev-knowledge-base
New-Item -ItemType Junction `
  -Path  "$env:USERPROFILE\.claude\skills\ogd-methodology" `
  -Target "$env:USERPROFILE\code\indie-gamedev-knowledge-base\OGD\ogd-methodology"
```

Для других инструментов меняй путь в `-Path`: `.cursor\skills\`, `.cline\skills\` и так далее. Junction подхватывает обновления через `git pull` так же, как симлинк.

## Лицензия

CC BY 4.0. Автор метода и скилла — Дмитрий Зайцев.
