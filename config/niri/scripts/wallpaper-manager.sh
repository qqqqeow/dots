#!/usr/bin/env bash
# ────────────── Wallpaper Manager (Awww + Wallhaven + Video mpvpaper) ──────────────

WALL_DIR="${HOME}/Изображения/wallpapers"
WALLHAVEN_DIR="${WALL_DIR}/wallhaven"
VIDEOS_DIR="${WALL_DIR}/videos"
NIRI_WALL_DIR="${HOME}/.config/niri/wallpapers"

mkdir -p "$WALL_DIR" "$WALLHAVEN_DIR" "$VIDEOS_DIR"

# Функция отправки уведомлений
notify() {
    if command -v notify-send &>/dev/null; then
        notify-send -a "Обои" -i "preferences-desktop-wallpaper" "$1" "$2"
    fi
}

# Остановка видео-обоев (mpvpaper), если запущены
stop_video() {
    if pgrep -x "mpvpaper" >/dev/null; then
        pkill -x mpvpaper
        sleep 0.2
    fi
}

# Установка статического изображения через awww/swww
apply_wallpaper() {
    local img="$1"
    if [ ! -f "$img" ]; then
        return 1
    fi

    stop_video

    local cmd="awww"
    local daemon="awww-daemon"
    if ! command -v awww &>/dev/null && command -v swww &>/dev/null; then
        cmd="swww"
        daemon="swww-daemon"
    fi

    if ! pgrep -x "$daemon" >/dev/null; then
        "$daemon" &
        sleep 0.5
    fi

    # Список плавных переходов
    local transitions=("grow" "wave" "wipe" "disc" "outer")
    local rand_transition=${transitions[$RANDOM % ${#transitions[@]}]}

    "$cmd" img "$img" \
        --transition-type "$rand_transition" \
        --transition-duration 1.5 \
        --transition-fps 60 \
        --transition-pos 0.5,0.5

    # Генерация палитры Matugen (если установлен)
    if command -v matugen &>/dev/null; then
        matugen image "$img" &>/dev/null &
    fi

    notify "Обои установлены" "$(basename "$img")"
}

# Случайные обои из локальной коллекции
random_wallpaper() {
    local all_wallpapers=()
    while IFS= read -r file; do
        all_wallpapers+=("$file")
    done < <(find "$WALL_DIR" "$NIRI_WALL_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" \) 2>/dev/null)

    if [ ${#all_wallpapers[@]} -eq 0 ]; then
        notify "Ошибка" "В папке обоев нет изображений."
        return 1
    fi

    local chosen="${all_wallpapers[$RANDOM % ${#all_wallpapers[@]}]}"
    apply_wallpaper "$chosen"
}

# Выбор локальных обоев через Fuzzel
pick_local_wallpaper() {
    local files
    files=$(find "$WALL_DIR" "$NIRI_WALL_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" -o -name "*.webp" \) 2>/dev/null | sort -u)
    if [ -z "$files" ]; then
        notify "Обои" "Локальные обои не найдены."
        return 1
    fi

    local chosen_name
    chosen_name=$(echo "$files" | while read -r f; do basename "$f"; done | fuzzel --dmenu --prompt "📁 Выберите обои: ")
    if [ -n "$chosen_name" ]; then
        local chosen_path
        chosen_path=$(echo "$files" | grep -m 1 "/${chosen_name}$")
        if [ -f "$chosen_path" ]; then
            apply_wallpaper "$chosen_path"
        fi
    fi
}

# Поиск и скачивание из Wallhaven API
fetch_wallhaven() {
    local query_type="$1"
    local search_param=""

    case "$query_type" in
        "top")
            search_param="sorting=toplist"
            ;;
        "hot")
            search_param="sorting=hot"
            ;;
        "anime")
            search_param="categories=010&sorting=toplist"
            ;;
        "cyberpunk")
            search_param="q=cyberpunk&sorting=toplist"
            ;;
        "search")
            local user_q
            user_q=$(fuzzel --dmenu --prompt "🔍 Поиск Wallhaven: ")
            [ -z "$user_q" ] && return 0
            search_param="q=$(echo "$user_q" | tr ' ' '+')&sorting=relevance"
            ;;
        *)
            search_param="sorting=toplist"
            ;;
    esac

    notify "Wallhaven" "Поиск обоев в каталоге..."

    local api_url="https://wallhaven.cc/api/v1/search?${search_param}&purity=100&resolutions=1920x1080,2560x1440,3840x2160&per_page=20"
    local response
    response=$(curl -s "$api_url")

    if [ -z "$response" ]; then
        notify "Ошибка" "Не удалось связаться с Wallhaven."
        return 1
    fi

    # Формируем список для Fuzzel
    local items
    items=$(echo "$response" | jq -r '.data[] | "\(.id) | \(.resolution) | \(.path)"')

    if [ -z "$items" ]; then
        notify "Wallhaven" "По вашему запросу ничего не найдено."
        return 0
    fi

    local display_list
    display_list=$(echo "$items" | awk -F ' \\| ' '{print $1 " (" $2 ")"}')

    local selected
    selected=$(echo "$display_list" | fuzzel --dmenu --prompt "🌐 Wallhaven [Выберите]: ")
    [ -z "$selected" ] && return 0

    local sel_id
    sel_id=$(echo "$selected" | awk '{print $1}')

    local direct_url
    direct_url=$(echo "$items" | grep "^${sel_id} " | awk -F ' \\| ' '{print $3}')

    if [ -n "$direct_url" ]; then
        local ext="${direct_url##*.}"
        local out_file="${WALLHAVEN_DIR}/wallhaven-${sel_id}.${ext}"

        notify "Wallhaven" "Загрузка полного изображения..."
        curl -s -o "$out_file" "$direct_url"

        if [ -f "$out_file" ]; then
            apply_wallpaper "$out_file"
        else
            notify "Ошибка" "Не удалось сохранить файл."
        fi
    fi
}

# Запуск видео-обоев через mpvpaper
play_video_wallpaper() {
    if ! command -v mpvpaper &>/dev/null; then
        notify "Ошибка" "Пакет mpvpaper не установлен."
        return 1
    fi

    local vids
    vids=$(find "$VIDEOS_DIR" -type f \( -name "*.mp4" -o -name "*.webm" -o -name "*.mkv" \) 2>/dev/null)

    if [ -z "$vids" ]; then
        notify "Видео-обои" "Поместите видео (.mp4/.webm) в ~/Изображения/wallpapers/videos/"
        return 1
    fi

    local chosen_vid_name
    chosen_vid_name=$(echo "$vids" | while read -r v; do basename "$v"; done | fuzzel --dmenu --prompt "🎬 Выберите видео: ")
    [ -z "$chosen_vid_name" ] && return 0

    local chosen_vid_path
    chosen_vid_path=$(echo "$vids" | grep -m 1 "/${chosen_vid_name}$")

    stop_video
    notify "Видео-обои" "Воспроизведение: $chosen_vid_name"
    mpvpaper -o "no-audio --loop-playlist shuffle --hwdec=auto" '*' "$chosen_vid_path" &
}

# Главное меню Fuzzel
show_menu() {
    local options=(
        "🎲 Случайные обои (с анимацией)"
        "📁 Локальная коллекция"
        "🌐 Wallhaven: Топ дня / недели"
        "🔥 Wallhaven: В тренде (Hot)"
        "🎨 Wallhaven: Аниме"
        "🌌 Wallhaven: Киберпанк & Sci-Fi"
        "🔍 Wallhaven: Поиск по слову..."
        "🎬 Запустить видео-обои (mpvpaper)"
        "⏹ Остановить видео-обои"
    )

    local choice
    choice=$(printf '%s\n' "${options[@]}" | fuzzel --dmenu --prompt "🖼️ Обои: ")
    [ -z "$choice" ] && exit 0

    case "$choice" in
        *"Случайные"*)
            random_wallpaper
            ;;
        *"Локальная"*)
            pick_local_wallpaper
            ;;
        *"Топ"*)
            fetch_wallhaven "top"
            ;;
        *"тренде"*)
            fetch_wallhaven "hot"
            ;;
        *"Аниме"*)
            fetch_wallhaven "anime"
            ;;
        *"Киберпанк"*)
            fetch_wallhaven "cyberpunk"
            ;;
        *"Поиск"*)
            fetch_wallhaven "search"
            ;;
        *"Запустить видео"*)
            play_video_wallpaper
            ;;
        *"Остановить видео"*)
            stop_video
            random_wallpaper
            ;;
    esac
}

# Обработка аргументов командной строки
case "$1" in
    "next"|"random")
        random_wallpaper
        ;;
    "menu"|"")
        show_menu
        ;;
    "stop-video")
        stop_video
        ;;
    "wallhaven")
        fetch_wallhaven "${2:-top}"
        ;;
    "video")
        play_video_wallpaper
        ;;
    *)
        if [ -f "$1" ]; then
            apply_wallpaper "$1"
        else
            show_menu
        fi
        ;;
esac
