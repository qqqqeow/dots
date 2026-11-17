#!/usr/bin/env python3
import json
import os
import sys

STATE_FILE = "/tmp/waybar_catwalk.state"

def get_cpu_and_mem():
    # Чтение CPU
    try:
        with open("/proc/stat", "r") as f:
            fields = [float(column) for column in f.readline().strip().split()[1:]]
        idle_time = fields[3] + fields[4]
        total_time = sum(fields)
    except Exception:
        idle_time, total_time = 0.0, 1.0

    # Чтение RAM
    ram_total = 0
    ram_avail = 0
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    ram_total = int(line.split()[1]) // 1024
                elif line.startswith("MemAvailable:"):
                    ram_avail = int(line.split()[1]) // 1024
    except Exception:
        pass
    ram_used = max(0, ram_total - ram_avail)
    ram_pct = int((ram_used / ram_total) * 100) if ram_total else 0

    # Вычисление дельты CPU по сохраненному состоянию
    prev_idle, prev_total, frame_idx = 0.0, 0.0, 0
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                parts = f.read().strip().split(",")
                prev_idle = float(parts[0])
                prev_total = float(parts[1])
                frame_idx = int(parts[2])
        except Exception:
            pass

    delta_idle = idle_time - prev_idle
    delta_total = total_time - prev_total
    cpu_pct = 0
    if delta_total > 0:
        cpu_pct = int((1.0 - delta_idle / delta_total) * 100)
    cpu_pct = max(0, min(100, cpu_pct))

    return cpu_pct, ram_used, ram_total, ram_pct, idle_time, total_time, frame_idx

def main():
    cpu_pct, ram_used, ram_total, ram_pct, idle_time, total_time, frame_idx = get_cpu_and_mem()

    # Наборы кадров анимации котика
    if cpu_pct < 30:
        # Спокойная походка котика
        frames = ["ᓚᘏᗢ", " ᓚᘏᗢ", "  ᓚᘏᗢ", "   ᓚᘏᗢ", "  ᓚᘏᗢ", " ᓚᘏᗢ"]
        css_class = "low"
    elif cpu_pct < 65:
        # Бодрый бег
        frames = ["🐾 ᓚᘏᗢ", " 🐾 ᓚᘏᗢ", "  🐾 ᓚᘏᗢ", " 🐾 ᓚᘏᗢ"]
        css_class = "medium"
    else:
        # Спринт при высокой нагрузке
        frames = ["ε=ε=┌( =^･ω･^=)┘", "ε=ε=┌( >_<)┘", "ᓚᘏᗢ 💨"]
        css_class = "high"

    current_frame = frames[frame_idx % len(frames)]
    next_frame_idx = (frame_idx + 1) % len(frames)

    # Сохраняем состояние
    try:
        with open(STATE_FILE, "w") as f:
            f.write(f"{idle_time},{total_time},{next_frame_idx}")
    except Exception:
        pass

    tooltip = (
        f"🐱 Catwalk Monitor\n"
        f"────────────────────────\n"
        f"󰍛 CPU: {cpu_pct}%\n"
        f"󰘚 RAM: {ram_used} МБ / {ram_total} МБ ({ram_pct}%)\n"
        f"────────────────────────\n"
        f"Нажмите: открыть диспетчер btop"
    )

    data = {
        "text": current_frame,
        "tooltip": tooltip,
        "class": css_class,
        "percentage": cpu_pct
    }
    print(json.dumps(data, ensure_ascii=False))

if __name__ == "__main__":
    main()
