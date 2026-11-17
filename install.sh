#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#   Niri Custom Setup Installer (Clean & Modular, No Noctalia)
#   CachyOS / Arch Linux
# ═══════════════════════════════════════════════════════════════════

set -e

# Цвета для вывода
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${HOME}/.config/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║        Niri Desktop Environment Installer (v1.1)        ║"
echo "  ║   Glassmorphism • Kitty • Wallhaven • No Noctalia        ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Проверка запуска от root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}[!] Не запускайте весь скрипт от root (sudo ./install.sh)!${NC}"
    echo -e "    Запустите скрипт от вашего обычного пользователя: ${BOLD}./install.sh${NC}"
    echo -e "    Скрипт сам запросит права sudo при установке пакетов."
    exit 1
fi

# 1. Проверка пакетного менеджера и установка пакетов
echo -e "${BLUE}[1/5] Проверка зависимостей и установка пакетов...${NC}"
if [ -f "${DOTFILES_DIR}/packages.txt" ]; then
    if command -v pacman &>/dev/null; then
        echo -e "  Установка необходимых пакетов через pacman..."
        sudo pacman -S --needed --noconfirm - < "${DOTFILES_DIR}/packages.txt"
        echo -e "${GREEN}  ✓ Пакеты успешно установлены.${NC}"
    else
        echo -e "${YELLOW}  [!] pacman не найден. Пропуск автоматической установки пакетов.${NC}"
    fi
else
    echo -e "${YELLOW}  [!] Файл packages.txt не найден.${NC}"
fi

# 2. Очистка и бэкап старых конфигураций
echo -e "\n${BLUE}[2/5] Резервное копирование существующих конфигураций...${NC}"
CONFIGS=("niri" "waybar" "swaync" "fuzzel" "swayosd" "kitty" "noctalia")
BACKUP_CREATED=false

for cfg in "${CONFIGS[@]}"; do
    TARGET="${HOME}/.config/${cfg}"
    if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
        if [ "$BACKUP_CREATED" = false ]; then
            mkdir -p "$BACKUP_DIR"
            BACKUP_CREATED=true
        fi
        echo -e "  Бэкап: ${TARGET} -> ${BACKUP_DIR}/${cfg}"
        mv "$TARGET" "${BACKUP_DIR}/${cfg}"
    fi
done

if [ "$BACKUP_CREATED" = true ]; then
    echo -e "${GREEN}  ✓ Старые конфигурации сохранены в: ${BACKUP_DIR}${NC}"
else
    echo -e "${GREEN}  ✓ Предыдущих конфликтующих конфигураций не обнаружено.${NC}"
fi

# Отключение Noctalia из автозапуска systemd (если была включена)
if systemctl --user is-enabled noctalia &>/dev/null; then
    echo -e "  Отключение службы Noctalia в systemd..."
    systemctl --user disable --now noctalia &>/dev/null || true
fi

# 3. Создание символических ссылок (Symlinks)
echo -e "\n${BLUE}[3/5] Развертывание конфигураций (символические ссылки)...${NC}"
mkdir -p "${HOME}/.config"

for dir in "${DOTFILES_DIR}/config"/*; do
    if [ -d "$dir" ]; then
        NAME="$(basename "$dir")"
        echo -e "  Линковка: ${NAME} -> ~/.config/${NAME}"
        ln -sfn "$dir" "${HOME}/.config/${NAME}"
    fi
done
echo -e "${GREEN}  ✓ Конфигурации успешно связаны.${NC}"

# 4. Настройка обоев и прав на скрипты
echo -e "\n${BLUE}[4/5] Подготовка каталогов обоев и скриптов...${NC}"
mkdir -p "${HOME}/Изображения/wallpapers/videos"
mkdir -p "${HOME}/Изображения/wallpapers/wallhaven"

if [ -d "${DOTFILES_DIR}/wallpapers" ]; then
    cp -r "${DOTFILES_DIR}/wallpapers"/* "${HOME}/Изображения/wallpapers/" 2>/dev/null || true
    echo -e "${GREEN}  ✓ Базовые обои скопированы в ~/Изображения/wallpapers${NC}"
fi

# Делаем скрипты исполняемыми
find "${DOTFILES_DIR}" -type f -name "*.sh" -exec chmod +x {} +
find "${DOTFILES_DIR}" -type f -name "*.py" -exec chmod +x {} +
echo -e "${GREEN}  ✓ Права на запуск скриптов установлены.${NC}"

# Включение аудиосервисов pipewire
systemctl --user enable --now pipewire pipewire-pulse wireplumber &>/dev/null || true

# 5. Валидация конфигурации Niri
echo -e "\n${BLUE}[5/5] Валидация конфигурации Niri...${NC}"
if command -v niri &>/dev/null; then
    if niri validate -c "${HOME}/.config/niri/config.kdl"; then
        echo -e "${GREEN}  ✓ Конфигурация Niri проверена и полностью валидна!${NC}"
    else
        echo -e "${RED}  [!] Ошибка валидации Niri. Проверьте ~/.config/niri/config.kdl${NC}"
    fi
fi

# Итоговый вывод
echo -e "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "\n${BOLD}Основные горячие клавиши:${NC}"
echo -e "  • ${BOLD}Mod + Enter${NC}          - Терминал Kitty (акриловое стекло)"
echo -e "  • ${BOLD}Mod + Space${NC}          - Меню приложений (Fuzzel)"
echo -e "  • ${BOLD}Mod + N${NC}              - Центр управления и уведомления (SwayNC)"
echo -e "  • ${BOLD}Mod + V${NC}              - История буфера обмена (Cliphist)"
echo -e "  • ${BOLD}Mod + W${NC}              - Меню обоев (Случайные / Wallhaven / Видео)"
echo -e "  • ${BOLD}Mod + Shift + W${NC}      - Следующие случайные обои с плавной анимацией"
echo -e "  • ${BOLD}Mod + Стрелки (←↑→↓)${NC}  - Навигация по окнам, колонкам и мониторам"
echo -e "  • ${BOLD}Mod + 1 .. 5${NC}         - Переключение рабочих столов"
echo -e "  • ${BOLD}Mod + [ / ]${NC}          - Переключение между экранами/мониторами"
echo -e "  • ${BOLD}Mod + Q${NC}              - Закрыть активное окно"
echo -e "  • ${BOLD}Mod + R${NC}              - Переключение ширины колонки (33% / 50% / 66%)"
echo -e "  • ${BOLD}Print${NC}                - Скриншот области в буфер"
echo -e "  • ${BOLD}Mod + Shift + E${NC}      - Выход из Niri"
echo -e "\n${BOLD}Панель Waybar сверху:${NC}"
echo -e "  • ${CYAN}Воркспейсы (1, 2, 3...)${NC}: клик для перехода, скролл колесиком"
echo -e "  • ${CYAN}Музыка (MPRIS)${NC}: клик по названию — Pause/Play, правый клик — Next"
echo -e "  • ${CYAN}Котик (Catwalk)${NC}: бежит быстрее при нагрузке CPU, клик открывает btop"
echo -e "  • ${CYAN}Уведомления (󰂚)${NC}: клик открывает шторку Control Center"
echo -e "\n${BOLD}Как запустить:${NC}"
echo -e "  • Если вы в TTY консоли: ${BOLD}niri-session${NC}"
echo -e "  • Если в дисплейном менеджере (SDDM/GDM): выберите сессию ${BOLD}Niri${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"
