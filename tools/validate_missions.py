#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Валидатор JSON-конфигов миссий.

Скрипт читает JSON-массив миссий и проверяет логику порогов и параметров
до запуска игры: обязательные поля, типы чисел, порядок порогов, ширину,
длительность и уникальность id.

Используются только стандартные библиотеки Python. Код возврата:
0 — все миссии валидны, 1 — найдены ошибки или файл не удалось прочитать.
"""

import argparse
import json
import sys

# Поля, которые обязаны присутствовать в каждой миссии.
REQUIRED_FIELDS = ("id", "off_threshold", "on_threshold", "width", "duration")

# Поля, значения которых обязаны быть числами.
NUMERIC_FIELDS = ("off_threshold", "on_threshold", "width", "duration")


def is_number(value) -> bool:
    """Проверяет, что значение — настоящее число, а не строка и не bool."""
    # bool в Python является подклассом int, но в конфиге это не число.
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def is_finite(value) -> bool:
    """Проверяет, что число конечно (не NaN и не бесконечность)."""
    # NaN не равен самому себе, а бесконечности сравниваем напрямую,
    # чтобы не подключать модуль math.
    return value == value and value not in (float("inf"), float("-inf"))


def is_usable_number(value) -> bool:
    """Число, с которым безопасно сравнивать: настоящий тип и конечное значение."""
    return is_number(value) and is_finite(value)


def format_number(value) -> str:
    """Форматирует число для сообщения об ошибке без лишних нулей."""
    if isinstance(value, float):
        text = "{:.6f}".format(value).rstrip("0")
        return text + "0" if text.endswith(".") else text
    return str(value)


def mission_label(mission, index: int) -> str:
    """
    Возвращает читаемую метку миссии для сообщения об ошибке.

    Если id уже есть и он непустой — используем его, иначе номер по порядку.
    """
    if isinstance(mission, dict):
        mission_id = mission.get("id")
        if isinstance(mission_id, str) and mission_id.strip():
            return "'{}'".format(mission_id.strip())
    return "#{}".format(index + 1)


def validate_mission(mission, index: int):
    """
    Проверяет одну миссию и возвращает список текстов ошибок.

    Функция не печатает и не завершает программу: решение о выводе
    и коде возврата принимает main().
    """
    label = mission_label(mission, index)

    # Миссия обязана быть объектом JSON, иначе остальные правила неприменимы.
    if not isinstance(mission, dict):
        return ["[ERROR] mission {}: expected an object, got {}".format(
            label, type(mission).__name__)]

    errors = []

    # 1. Все обязательные поля присутствуют.
    for field in REQUIRED_FIELDS:
        if field not in mission:
            errors.append("[ERROR] mission {}: missing required field '{}'".format(
                label, field))

    # 2. Числовые поля должны быть числами, а не строками и не bool.
    for field in NUMERIC_FIELDS:
        if field not in mission:
            continue  # отсутствие поля уже отмечено выше
        value = mission[field]
        if not is_number(value):
            errors.append(
                "[ERROR] mission {}: {} must be a number, got {}".format(
                    label, field, type(value).__name__))
        elif not is_finite(value):
            errors.append(
                "[ERROR] mission {}: {} must be a finite number, got {}".format(
                    label, field, format_number(value)))

    # 3. id должен быть непустой строкой.
    mission_id = mission.get("id")
    if "id" in mission:
        if not isinstance(mission_id, str):
            errors.append(
                "[ERROR] mission {}: id must be a non-empty string, got {}".format(
                    label, type(mission_id).__name__))
        elif not mission_id.strip():
            errors.append("[ERROR] mission {}: id must not be empty".format(label))

    # Значения проверяем только если оба порога уже подтверждены как числа,
    # чтобы не сравнивать строки и не получить неожиданный результат.
    off = mission.get("off_threshold")
    on = mission.get("on_threshold")
    if is_usable_number(off) and is_usable_number(on):
        # 4. on_threshold строго больше off_threshold, иначе миссию не пройти.
        if not on > off:
            errors.append(
                "[ERROR] mission {}: on_threshold ({}) must be > off_threshold ({})".format(
                    label, format_number(on), format_number(off)))

    width = mission.get("width")
    if is_usable_number(width):
        # 5. Ширина строго больше 0 и не больше 1.0.
        if not (0 < width <= 1.0):
            errors.append(
                "[ERROR] mission {}: width ({}) must be > 0 and <= 1.0".format(
                    label, format_number(width)))

    duration = mission.get("duration")
    if is_usable_number(duration):
        # 6. Длительность строго больше 0.
        if not duration > 0:
            errors.append(
                "[ERROR] mission {}: duration ({}) must be > 0".format(
                    label, format_number(duration)))

    return errors


def load_missions(path: str):
    """
    Читает JSON-файл и возвращает (данные, None) либо (None, текст ошибки).

    Все ошибки чтения и разбора перехватываются, чтобы не было трейсбека.
    """
    try:
        # utf-8-sig читает и обычный UTF-8, и файлы с BOM (их часто создают
        # редакторы Windows). Без этого json.load падает на первом символе.
        with open(path, "r", encoding="utf-8-sig") as handle:
            return json.load(handle), None
    except FileNotFoundError:
        return None, "[ERROR] file '{}': not found".format(path)
    except IsADirectoryError:
        return None, "[ERROR] file '{}': is a directory".format(path)
    except PermissionError:
        return None, "[ERROR] file '{}': permission denied".format(path)
    except UnicodeDecodeError as exc:
        return None, "[ERROR] file '{}': not valid UTF-8 ({})".format(path, exc.reason)
    except json.JSONDecodeError as exc:
        return None, (
            "[ERROR] file '{}': invalid JSON at line {} column {}: {}".format(
                path, exc.lineno, exc.colno, exc.msg))
    except OSError as exc:
        return None, "[ERROR] file '{}': cannot read ({})".format(path, exc)


def validate_all(missions):
    """Проверяет весь список миссий и возвращает список ошибок."""
    errors = []
    seen_ids = {}

    for index, mission in enumerate(missions):
        errors.extend(validate_mission(mission, index))

        # 7. id должен быть уникальным. Сравниваем уже очищенные значения.
        if isinstance(mission, dict):
            mission_id = mission.get("id")
            if isinstance(mission_id, str) and mission_id.strip():
                key = mission_id.strip()
                if key in seen_ids:
                    errors.append(
                        "[ERROR] mission {}: duplicate id (first used by mission #{})".format(
                            mission_label(mission, index), seen_ids[key]))
                else:
                    seen_ids[key] = index + 1

    return errors


def parse_args():
    """Разбирает аргументы командной строки."""
    parser = argparse.ArgumentParser(
        description="Проверяет JSON-конфиг миссий на логические ошибки."
    )
    parser.add_argument(
        "--input",
        default="game/content/missions.json",
        help="путь к JSON-файлу миссий (по умолчанию: game/content/missions.json)",
    )
    return parser.parse_args()


def main() -> int:
    """Точка входа. Возвращает код завершения процесса."""
    args = parse_args()

    missions, error = load_missions(args.input)
    if error is not None:
        print(error, file=sys.stderr)
        return 1

    # Ожидается массив объектов; иначе проверять нечего.
    if not isinstance(missions, list):
        print(
            "[ERROR] file '{}': expected a JSON array of missions, got {}".format(
                args.input, type(missions).__name__),
            file=sys.stderr,
        )
        return 1

    errors = validate_all(missions)
    if errors:
        for message in errors:
            print(message, file=sys.stderr)
        return 1

    print("[OK] All {} missions are valid.".format(len(missions)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
