#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Генератор фейковых данных для тестирования интерфейса.

Создаёт папку mock_data/ и три JSON-файла:
- missions_mock.json  — 10 миссий с разной длиной названий и описаний;
- profiles_mock.json  — 5 профилей игроков, у одного длинный список рекордов;
- summary_mock.json   — экран результатов одной миссии.

Используются только стандартные библиотеки Python. Генерация
воспроизводима: одинаковый --seed даёт одинаковые файлы.
"""

import argparse
import json
import os
import random
import sys

# Папка и имена файлов заданы жёстко: так проще подключать моки в UI.
OUTPUT_DIR = "mock_data"
MISSIONS_FILE = "missions_mock.json"
PROFILES_FILE = "profiles_mock.json"
SUMMARY_FILE = "summary_mock.json"

# Заготовки миссий: id, название и описание разной длины (от 2 до ~50 слов).
# Числовые параметры подставляются генератором ниже.
MISSION_BLUEPRINTS = (
    {
        "id": "m1_heat",
        "title": "Клапан охлаждения",
        "description": "Перекройте подачу хладагента.",
    },
    {
        "id": "m2_pressure",
        "title": "Сброс давления",
        "description": (
            "Сбросьте давление в контуре до безопасного уровня "
            "и дождитесь стабилизации стрелки манометра."
        ),
    },
    {
        "id": "m3_valve",
        "title": "Ручной вентиль",
        "description": "Откройте вентиль на четверть оборота и удерживайте захват.",
    },
    {
        "id": "m4_cable",
        "title": "Кабель питания",
        "description": (
            "Аккуратно подведите захват к кабелю, приподнимите его над полом "
            "и заведите в разъём, не задев соседние контакты и датчики."
        ),
    },
    {
        "id": "m5_relay",
        "title": "Реле аварийного света",
        "description": (
            "Найдите реле аварийного освещения на нижней панели, освободите "
            "его от креплений и переставьте в резервный слот, соблюдая порядок "
            "контактов и не касаясь оголённых шин под напряжением."
        ),
    },
    {
        "id": "m6_panel",
        "title": "Съёмная панель",
        "description": (
            "Снимите защитную панель корпуса: открутите четыре винта по углам, "
            "придерживайте панель второй рукой, чтобы она не упала на датчики, "
            "и отложите её в сторону, не перекрывая проход к аварийному выходу."
        ),
    },
    {
        "id": "m7_filter",
        "title": "Замена фильтра тонкой очистки воздуха",
        "description": (
            "Извлеките отработанный фильтр тонкой очистки из гнезда, проверьте "
            "уплотнительное кольцо на наличие трещин и загрязнений, установите "
            "новый фильтр до щелчка фиксатора и убедитесь, что индикатор потока "
            "воздуха снова горит зелёным."
        ),
    },
    {
        "id": "m8_hatch",
        "title": "Шлюзовой люк",
        "description": (
            "Разблокируйте шлюзовой люк вручную: сдвиньте страховочную защёлку "
            "вверх, поверните маховик против часовой стрелки до упора и потяните "
            "створку на себя. Если створка не поддаётся, не применяйте силу, "
            "а проверьте остаточное давление в камере и сбросьте его через "
            "дренажный клапан, расположенный справа от люка."
        ),
    },
    {
        "id": "m9_console",
        "title": "Пульт управления",
        "description": (
            "Переведите пульт управления в сервисный режим, последовательно "
            "нажимая кнопки диагностики и подтверждая каждый шаг. Следите "
            "за сообщениями на экране: при появлении "
            "предупреждения остановитесь, запишите код ошибки и дождитесь "
            "подтверждения от старшего инженера. После завершения диагностики "
            "верните пульт в рабочий режим и проверьте, что все индикаторы "
            "снова горят ровным светом."
        ),
    },
    {
        "id": "m10_core",
        "title": "Аварийный контур реактора",
        "description": (
            "Проверьте целостность контура охлаждения, последовательно пройдите "
            "вдоль всех магистралей, отметьте повреждённые участки и замените "
            "уплотнители на фланцах. После замены уплотнителей запустите "
            "тестовую прокачку, прослушайте систему на предмет свиста и "
            "вибрации, запишите показания датчиков в журнал смены и передайте "
            "отчёт старшему инженеру станции в конце смены."
        ),
    },
)

# Идентификаторы профилей. Один игрок получит длинный список рекордов,
# чтобы дизайнер проверил прокрутку и обрезку длинных строк.
PLAYER_IDS = ("ranger_01", "novice_07", "veteran_13", "test_long_42", "guest_99")

# Варианты награды за миссию для экрана результатов.
UPGRADES = (
    "Мастерская напарника",
    "Усиленный захват",
    "Стабилизатор кисти",
    "Резервный аккумулятор",
)


def build_missions(rng):
    """Собирает 10 миссий с корректными и разнообразными параметрами."""
    missions = []
    for blueprint in MISSION_BLUEPRINTS:
        # off_threshold ниже on_threshold, иначе миссию нельзя пройти.
        off_threshold = round(rng.uniform(0.30, 0.55), 2)
        on_threshold = round(off_threshold + rng.uniform(0.10, 0.20), 2)
        missions.append({
            "id": blueprint["id"],
            "title": blueprint["title"],
            "description": blueprint["description"],
            "off_threshold": off_threshold,
            "on_threshold": on_threshold,
            "width": round(rng.uniform(0.15, 0.45), 2),
            "duration": round(rng.uniform(8.0, 30.0), 1),
        })
    return missions


def build_records(rng, count, missions):
    """Генерирует список записей игрока на основе названий миссий."""
    records = []
    for index in range(count):
        mission = missions[index % len(missions)]
        seconds = round(rng.uniform(5.0, 40.0), 1)
        records.append(
            "Запись #{} · {} · {} с".format(index, mission["title"], seconds)
        )
    return records


def build_profiles(rng, missions):
    """Собирает 5 профилей; у одного игрока 14 записей для проверки скролла."""
    profiles = []
    for index, player_id in enumerate(PLAYER_IDS):
        # У тестового игрока намеренно длинный список рекордов.
        if player_id == "test_long_42":
            record_count = 14
        else:
            record_count = rng.randint(0, 4)

        profiles.append({
            "player_id": player_id,
            "progress": rng.randint(0, 10),
            "adaptation_level": rng.randint(0, 3),
            "total_time_sec": round(rng.uniform(30.0, 900.0), 1),
            "records": build_records(rng, record_count, missions),
        })
    return profiles


def build_summary(rng, missions):
    """Собирает один экран результатов миссии."""
    mission = missions[0]
    return {
        "mission_id": mission["id"],
        "active_seconds": round(rng.uniform(6.0, 45.0), 1),
        "in_hold_percent": round(rng.uniform(40.0, 98.0), 1),
        "events_count": rng.randint(5, 120),
        "adaptation_delta": rng.choice((0.0, 0.1, 0.2, -0.1)),
        "upgrade_unlocked": rng.choice(UPGRADES),
    }


def write_json(path, data):
    """
    Записывает данные в JSON-файл.

    Возвращает True при успехе. Ошибки не пробрасываются наружу,
    чтобы main() мог аккуратно завершиться с кодом 1.
    """
    try:
        # ensure_ascii=False сохраняет русский текст читаемым,
        # indent=2 делает файл удобным для просмотра и диффов.
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(data, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        return True
    except OSError as exc:
        print("[ERROR] cannot write '{}': {}".format(path, exc), file=sys.stderr)
        return False


def parse_args():
    """Разбирает аргументы командной строки."""
    parser = argparse.ArgumentParser(
        description="Генерирует фейковые JSON-данные для тестирования UI."
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="зерно генерации для воспроизводимости (по умолчанию: 42)",
    )
    return parser.parse_args()


def main() -> int:
    """Точка входа. Возвращает код завершения процесса."""
    args = parse_args()
    rng = random.Random(args.seed)

    # Папку создаём до записи файлов; ошибки прав/диска обрабатываем явно.
    try:
        os.makedirs(OUTPUT_DIR, exist_ok=True)
    except OSError as exc:
        print("[ERROR] cannot create directory '{}': {}".format(OUTPUT_DIR, exc),
              file=sys.stderr)
        return 1

    # Проверяем, что путь существует и является папкой, а не файлом.
    if not os.path.isdir(OUTPUT_DIR):
        print("[ERROR] '{}' exists and is not a directory".format(OUTPUT_DIR),
              file=sys.stderr)
        return 1

    missions = build_missions(rng)
    profiles = build_profiles(rng, missions)
    summary = build_summary(rng, missions)

    files = (
        (MISSIONS_FILE, missions),
        (PROFILES_FILE, profiles),
        (SUMMARY_FILE, summary),
    )

    for name, data in files:
        path = os.path.join(OUTPUT_DIR, name)
        if not write_json(path, data):
            return 1
        # Для массива показываем число элементов, для объекта — «1 object».
        if isinstance(data, list):
            summary_text = "{} items".format(len(data))
        else:
            summary_text = "1 object"
        print("[OK] wrote {} ({})".format(path, summary_text))

    print("[OK] mock data generated with seed {}".format(args.seed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
