#!/usr/bin/env python3
"""
Обновление OGD-скилла: копирование исходников + генерация навигационной карты.

1. Копирует нужные файлы из репозитория в ogd-methodology/references/
2. Генерирует navigation-map.md по содержимому references/

Запуск из корня репозитория (my-guides/):
    python3 OGD/ogd-methodology/scripts/update.py

Или через Makefile:
    make update-ogd-skill
"""

import re
import shutil
from pathlib import Path

# ─────────────────────────────────────────────────────────
# КОНФИГУРАЦИЯ: что копировать в references/
# Пути относительно корня репозитория (my-guides/)
# ─────────────────────────────────────────────────────────

# Ядро OGD (копируются в references/ напрямую)
OGD_CORE_FILES = [
    "OGD/OGD.md",
    "OGD/GLOSSARY.md",
    "OGD/QUICKSTART.md",
    "OGD/FAQ.md",
    "OGD/Pacing.md",
    "OGD/Progression.md",
]

# Статьи, сильно связанные с OGD (копируются в references/articles/)
# Критерий: статья напрямую использует фреймворк OGD (термины, протоколы, сферы)
OGD_ARTICLES = [
    # Из OGD/articles/
    "OGD/articles/ogd-kontekst-i-realnost.md",
    # Из Guides/ — только сильно связанные с OGD
    "Guides/GameDesign/ogd-and-pens-sdt.md",
    "Guides/GameDesign/ogd-and-game-design-paradoxes.md",
    "Guides/GameDesign/core-loop-and-concept.md",
    "Guides/GameDesign/cozy-vs-casual-mechanics.md",
    "Guides/GameDesign/safe-space-mechanic.md",
    "Guides/GameDesign/cognitive-load-retention.md",
    "Guides/GameDesign/serotonin-vs-dopamine-fat.md",
    "Guides/GameDesign/case-study-galaxy-burger-memory-trap.md",
    "Guides/GameDesign/durak-balatro-ogd-case.md",
    "Guides/GameDesign/asmr-sensory-design.md",
    "Guides/GameDesign/timers-and-pacing.md",
    "Guides/General/game-as-therapy-and-shelter.md",
]

# ─────────────────────────────────────────────────────────


def find_repo_root(script_path: Path) -> Path:
    """Ищет корень репозитория (my-guides/) от расположения скрипта."""
    # Скрипт: OGD/ogd-methodology/scripts/update.py → корень = 3 уровня вверх
    root = script_path.parent.parent.parent.parent
    if (root / "OGD" / "OGD.md").exists():
        return root
    cwd = Path.cwd()
    if (cwd / "OGD" / "OGD.md").exists():
        return cwd
    raise FileNotFoundError(
        "Не могу найти корень репозитория (my-guides/). "
        "Запусти скрипт из корня или проверь структуру."
    )


def copy_references(repo_root: Path, skill_dir: Path) -> list[Path]:
    """Копирует исходники в references/. Возвращает список скопированных файлов."""
    refs_dir = skill_dir / "references"
    articles_dir = refs_dir / "articles"

    # Сохраняем NAVIGATION.md (он ручной, не автогенерируемый)
    nav_file = refs_dir / "NAVIGATION.md"
    nav_backup = None
    if nav_file.exists():
        nav_backup = nav_file.read_text(encoding="utf-8")

    # Очищаем references/ перед копированием
    if refs_dir.exists():
        shutil.rmtree(refs_dir)
    refs_dir.mkdir(parents=True)
    articles_dir.mkdir(parents=True)

    # Восстанавливаем NAVIGATION.md
    if nav_backup:
        nav_file.write_text(nav_backup, encoding="utf-8")

    copied = []

    # Ядро OGD
    for rel in OGD_CORE_FILES:
        src = repo_root / rel
        dst = refs_dir / Path(rel).name
        if src.exists():
            shutil.copy2(src, dst)
            copied.append(dst)
            print(f"  ✓ {rel} → references/{dst.name}")
        else:
            print(f"  ✗ {rel} — не найден, пропускаю")

    # Статьи
    for rel in OGD_ARTICLES:
        src = repo_root / rel
        dst = articles_dir / Path(rel).name
        if src.exists():
            shutil.copy2(src, dst)
            copied.append(dst)
            print(f"  ✓ {rel} → references/articles/{dst.name}")
        else:
            print(f"  ✗ {rel} — не найден, пропускаю")

    return copied


def extract_sections(filepath: Path, base_dir: Path) -> list[dict]:
    """Извлекает заголовки и якоря из .md файла."""
    sections = []
    rel_path = filepath.relative_to(base_dir)

    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    pending_anchor = None

    for i, line in enumerate(lines, start=1):
        anchor_match = re.search(r'<a\s+name="([^"]+)"', line)
        if anchor_match:
            pending_anchor = anchor_match.group(1)

        header_match = re.match(r'^(#{1,4})\s+(.+)$', line)
        if header_match:
            level = len(header_match.group(1))
            title = header_match.group(2).strip()
            title = re.sub(r'<a\s+name="[^"]+"\s*>\s*</a>\s*', '', title).strip()
            title = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', title)
            title = re.sub(r'`[^`]+`', '', title).strip()

            if not title:
                continue

            anchor = pending_anchor or ""
            pending_anchor = None

            sections.append({
                "file": str(rel_path),
                "line": i,
                "level": level,
                "title": title,
                "anchor": anchor,
            })
        elif pending_anchor and line.strip() and not anchor_match:
            pending_anchor = None

    return sections


def generate_map(refs_dir: Path) -> str:
    """Генерирует navigation-map.md по содержимому references/."""
    lines = [
        "# Навигационная карта OGD",
        "",
        "> Файл сгенерирован автоматически скриптом `scripts/update.py`.",
        "> Не редактируй вручную — перезапусти скрипт после обновления исходников.",
        "",
        "Карта заголовков и якорей файлов из `references/` с номерами строк.",
        "",
        "---",
        "",
    ]

    core_files = sorted(
        [f for f in refs_dir.glob("*.md") if f.name != "NAVIGATION.md"],
        key=lambda p: (0 if p.name == "OGD.md" else 1, p.name),
    )
    article_files = sorted((refs_dir / "articles").glob("*.md"))

    all_groups = [
        ("Ядро методологии", core_files),
        ("Статьи (OGD-связанные)", article_files),
    ]

    for section_title, files in all_groups:
        if not files:
            continue

        lines.append(f"## {section_title}")
        lines.append("")

        for filepath in files:
            sections = extract_sections(filepath, refs_dir)

            with open(filepath, "r", encoding="utf-8") as f:
                total = sum(1 for _ in f)

            rel = filepath.relative_to(refs_dir)
            lines.append(f"### `references/{rel}` ({total} строк)")
            lines.append("")

            if not sections:
                lines.append("*(нет заголовков)*")
                lines.append("")
                continue

            lines.append("| Строка | Якорь | Заголовок |")
            lines.append("|--------|-------|-----------|")

            for s in sections:
                if s["level"] == 0:
                    continue
                indent = "&nbsp;&nbsp;" * max(0, s["level"] - 2)
                anchor_str = f"`{s['anchor']}`" if s["anchor"] else "—"
                title_str = f"{indent}{'#' * s['level']} {s['title']}"
                lines.append(f"| {s['line']} | {anchor_str} | {title_str} |")

            lines.append("")

    return "\n".join(lines)


def main():
    script_path = Path(__file__).resolve()
    repo_root = find_repo_root(script_path)
    skill_dir = repo_root / "OGD" / "ogd-methodology"

    print(f"Корень репозитория: {repo_root}")
    print(f"Папка скилла: {skill_dir}")
    print()

    # 1. Копируем исходники
    print("Копирую исходники в references/...")
    copy_references(repo_root, skill_dir)
    print()

    # 2. Генерируем карту
    print("Генерирую navigation-map.md...")
    content = generate_map(skill_dir / "references")
    map_path = skill_dir / "navigation-map.md"
    with open(map_path, "w", encoding="utf-8") as f:
        f.write(content)

    line_count = content.count("\n") + 1
    print(f"Готово: navigation-map.md ({line_count} строк)")


if __name__ == "__main__":
    main()
