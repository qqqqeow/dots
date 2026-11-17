#!/usr/bin/env bash
# ────────────── Wallpaper Init Script ──────────────

# Определяем команду для обоев (awww или swww)
if command -v awww &>/dev/null; then
    WALL_CMD="awww"
    DAEMON_CMD="awww-daemon"
elif command -v swww &>/dev/null; then
    WALL_CMD="swww"
    DAEMON_CMD="swww-daemon"
else
    echo "Ни awww, ни swww не найдены."
    exit 0
fi

# Проверяем и запускаем демон, если он не запущен
if ! pgrep -x "$DAEMON_CMD" >/dev/null; then
    "$DAEMON_CMD" &
    sleep 0.5
fi

# Ждем пока сокет демона ответит (до 3 секунд)
for i in {1..15}; do
    if "$WALL_CMD" query &>/dev/null; then
        break
    fi
    sleep 0.2
done

# Пути поиска обоев
WALL_DIR="${HOME}/.config/niri/wallpapers"
ALT_DIR="${HOME}/Изображения/wallpapers"

WALLPAPER=""
if [ -d "$WALL_DIR" ]; then
    WALLPAPER=$(find "$WALL_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) | head -n 1)
fi

if [ -z "$WALLPAPER" ] && [ -d "$ALT_DIR" ]; then
    WALLPAPER=$(find "$ALT_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) | head -n 1)
fi

# Если обои найдены, устанавливаем с плавным переходом
if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
    "$WALL_CMD" img "$WALLPAPER" \
        --transition-type grow \
        --transition-pos 0.5,0.5 \
        --transition-step 90 \
        --transition-fps 60
    
    # Генерация палитры Matugen (если установлен)
    if command -v matugen &>/dev/null; then
        matugen image "$WALLPAPER" &>/dev/null &
    fi
fi
