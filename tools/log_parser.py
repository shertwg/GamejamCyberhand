#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Фильтр логов Android/Godot.

Скрипт читает текстовый лог, оставляет только строки с ключевыми словами
(ошибки, предупреждения, сообщения движка Godot) и сохраняет их в Markdown.
Используются только стандартные библиотеки Python.
"""

import argparse
import os
import re
import sys
from datetime import datetime

# Ключевые слова для фильтрации. Сравнение всегда идёт без учёта регистра.
KEYWORDS = (
    "godot",
    "error",
    "warning",
    "fatal",
    "exception",
    "crash",
    "parse json failed",
)

# Регулярные выражения для поиска времени в строке.
# Порядок важен: сначала пробуем самый полный формат.
TIME_PATTERNS = (
    # 2026-11-08 12:34:56.789 или 2026-11-08T12:34:56,789
    re.compile(r"\b(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[.,]\d{1,6})?)\b"),
    # logcat: 11-08 12:34:56.789
    re.compile(r"\b(\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?)\b"),
    # Только время: 12:34:56.789
    re.compile(r"\b(\d{2}:\d{2}:\d{2}(?:[.,]\d{1,6})?)\b"),
)

# ANSI-последовательности для раскраски консоли.
COLORS = {
    "ERROR": "\033[91m",  # ярко-красный
    "WARN": "\033[93m",   # жёлтый
    "INFO": "\033[97m",   # белый
}
RESET = "\033[0m"


def supports_color() -> bool:
    """Проверяет, можно ли использовать ANSI-цвета в текущей консоли."""
    # Явный запрет через переменную окружения (общепринятый стандарт NO_COLOR).
    if os.environ.get("NO_COLOR"):
        return False
    # TERM=dumb означает консоль без поддержки escape-последовательностей.
    if os.environ.get("TERM") == "dumb":
        return False
    # Если вывод перенаправлен в файл или pipe, цвета не нужны.
    if not sys.stdout.isatty():
        return False
    if os.name == "nt":
        # В Windows 10+ вызов пустой команды включает обработку ANSI-кодов
        # в классической консоли. В Windows Terminal они работают и так.
        os.system("")
    return True


def classify(line_lower: str) -> str:
    """Определяет уровень строки: ERROR, WARN или INFO."""
    # "Parse JSON failed" — известная ожидаемая ошибка проекта,
    # поэтому относим её к ошибкам, но отдельно считаем в сводке.
    if "parse json failed" in line_lower:
        return "ERROR"
    if any(word in line_lower for word in ("error", "fatal", "exception", "crash")):
        return "ERROR"
    if "warning" in line_lower:
        return "WARN"
    return "INFO"


def split_time(line: str):
    """
    Отделяет время от сообщения.

    Возвращает пару (время, сообщение). Если время не найдено,
    возвращает ('-', исходная строка).
    """
    for pattern in TIME_PATTERNS:
        match = pattern.search(line)
        if match:
            time_value = match.group(1)
            # Убираем найденное время из текста, чтобы не дублировать его
            # в консоли и в колонке "Сообщение" Markdown-таблицы.
            message = (line[:match.start()] + line[match.end():]).strip()
            message = re.sub(r"\s{2,}", " ", message)
            if message:
                return time_value, message
    return "-", line


def escape_markdown(text: str) -> str:
    """Экранирует символы, которые ломают таблицу Markdown."""
    return text.replace("|", "\\|")


def read_log(path: str):
    """
    Читает файл построчно.

    Возвращает список строк или None, если файл не найден/не читается.
    Ошибки печатаются в stderr, чтобы не смешивать их с результатом.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            return handle.readlines()
    except FileNotFoundError:
        print("Ошибка: файл не найден: {}".format(path), file=sys.stderr)
    except IsADirectoryError:
        print("Ошибка: указанный путь является папкой: {}".format(path), file=sys.stderr)
    except PermissionError:
        print("Ошибка: нет прав на чтение файла: {}".format(path), file=sys.stderr)
    except OSError as exc:
        print("Ошибка чтения файла {}: {}".format(path, exc), file=sys.stderr)
    return None


def write_markdown(path: str, content: str) -> bool:
    """Сохраняет Markdown-отчёт. Возвращает True при успехе."""
    try:
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
        return True
    except OSError as exc:
        print("Ошибка записи файла {}: {}".format(path, exc), file=sys.stderr)
        return False


def build_markdown(input_path: str, output_path: str, total: int, matched, errors: int,
                   warnings: int, parse_json: int, created: datetime) -> str:
    """Формирует содержимое Markdown-отчёта."""
    lines = [
        "# Сводка лога",
        "",
        "- Исходный файл: `{}`".format(input_path),
        "- Сформировано: {}".format(created.strftime("%Y-%m-%d %H:%M:%S")),
        "- Всего строк прочитано: {}".format(total),
        "- Ошибок: {}".format(errors),
        "- Предупреждений: {}".format(warnings),
        "- Parse JSON failed: {}".format(parse_json),
        "",
        "| Время | Уровень | Сообщение |",
        "| --- | --- | --- |",
    ]

    if matched:
        for time_value, level, message in matched:
            lines.append("| {} | {} | {} |".format(
                escape_markdown(time_value),
                level,
                escape_markdown(message),
            ))
    else:
        lines.append("| - | - | Совпадений не найдено |")

    return "\n".join(lines) + "\n"


def parse_args():
    """Разбирает аргументы командной строки."""
    parser = argparse.ArgumentParser(
        description="Фильтрует лог Android/Godot и сохраняет сводку в Markdown."
    )
    parser.add_argument(
        "--input",
        default="godot.log",
        help="путь к файлу лога (по умолчанию: godot.log)",
    )
    parser.add_argument(
        "--output",
        default=None,
        help=("путь к Markdown-файлу; по умолчанию создаётся "
              "log_summary_YYYY-MM-DD_HH-MM.md"),
    )
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="отключить цвета в консоли",
    )
    return parser.parse_args()


def main() -> int:
    """Точка входа. Возвращает код завершения процесса."""
    args = parse_args()
    created = datetime.now()

    # Если --output не передан, используем имя с датой и временем,
    # чтобы отчёты разных запусков не перезаписывали друг друга.
    output_path = args.output or "log_summary_{}.md".format(
        created.strftime("%Y-%m-%d_%H-%M")
    )

    raw_lines = read_log(args.input)
    if raw_lines is None:
        return 1

    matched = []
    for raw_line in raw_lines:
        line = raw_line.strip()
        if not line:
            continue

        line_lower = line.lower()
        if not any(keyword in line_lower for keyword in KEYWORDS):
            continue

        time_value, message = split_time(line)
        matched.append((time_value, classify(line_lower), message))

    # Считаем статистику по уже отфильтрованным строкам.
    errors = sum(1 for _, level, _ in matched if level == "ERROR")
    warnings = sum(1 for _, level, _ in matched if level == "WARN")
    parse_json = sum(1 for _, _, message in matched
                     if "parse json failed" in message.lower())

    # Печатаем результат в консоль.
    use_color = not args.no_color and supports_color()
    for time_value, level, message in matched:
        prefix = "[{}]".format(level)
        time_part = "" if time_value == "-" else "{} ".format(time_value)
        if use_color:
            print("{}{}{} {}{}".format(
                COLORS.get(level, ""), prefix, RESET, time_part, message
            ))
        else:
            print("{} {}{}".format(prefix, time_part, message))

    # Сохраняем Markdown-отчёт.
    markdown = build_markdown(
        args.input, output_path, len(raw_lines), matched,
        errors, warnings, parse_json, created,
    )
    if not write_markdown(output_path, markdown):
        return 1

    # Краткая сводка в конце.
    print("")
    print("Всего строк прочитано: {}".format(len(raw_lines)))
    print("Ошибок: {}".format(errors))
    print("Предупреждений: {}".format(warnings))
    print("Parse JSON failed: {}".format(parse_json))
    print("Markdown-отчёт: {}".format(output_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
