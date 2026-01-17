#!/bin/bash

case "$1" in
    "--help"|"-h")
        echo "PSP Widgets Client"
        echo ""
        echo "Usage: $0 [OPTION]"
        echo ""
        echo "Options:"
        echo "  --install       Install application (create desktop shortcut and autostart)"
        echo "  --autostart     Start in background (for autostart)"
        echo "  --help          Show this help message"
        echo ""
        echo "Without options: Start interactive GUI"
        exit 0
        ;;
    "--install")
        mkdir -p "$HOME/.config/autostart"
        cat > "$HOME/.config/autostart/psp-widgets.desktop" << EOF
[Desktop Entry]
Type=Application
Name=PSP Widgets Client
Exec="$PWD/$(basename "$0") --autostart"
Comment=Update PSP widgets status
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
        
        mkdir -p "$HOME/.local/share/applications"
        cat > "$HOME/.local/share/applications/psp-widgets.desktop" << EOF
[Desktop Entry]
Type=Application
Name=PSP Widgets Client
Exec="$PWD/$(basename "$0")"
Icon=computer
Terminal=false
Categories=Utility;
EOF
        
        chmod +x "$HOME/.local/share/applications/psp-widgets.desktop"
        echo "Installation complete"
        echo "Shortcut created in applications menu"
        echo "Autostart configured"
        exit 0
        ;;
esac


CONFIG_FILE="$HOME/.config/psp_widgets.conf"
CACHE_DIR="$HOME/.cache/psp_widgets"
PID_FILE="$CACHE_DIR/background.pid"
LOG_FILE="$CACHE_DIR/background.log"
mkdir -p "$CACHE_DIR"

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        PSP_MOUNT=""
        HOMEBREW_PATH="PSP/GAME/widgets_portable"
        UPDATE_INTERVAL=3
        AUTO_MODE=false
    fi
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
PSP_MOUNT="$PSP_MOUNT"
HOMEBREW_PATH="$HOMEBREW_PATH"
UPDATE_INTERVAL=$UPDATE_INTERVAL
AUTO_MODE=$AUTO_MODE
EOF
}

check_psp_connected() {
    if [ -n "$PSP_MOUNT" ] && [ -d "$PSP_MOUNT" ]; then
        if [ -d "$PSP_MOUNT/PSP" ] || [ -d "$PSP_MOUNT/ux0" ]; then
            return 0
        fi
    fi
    return 1
}

get_cpu_usage() {
    echo "$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d'.' -f1)%"
}

get_ram_usage() {
    local total=$(free -m | awk '/Mem:/ {print $2}')
    local used=$(free -m | awk '/Mem:/ {print $3}')
    local percent=$((used * 100 / total))
    echo "${used}M/${total}M (${percent}%)"
}

get_gpu_usage() {
    local usage="0"

    if command -v nvidia-smi &>/dev/null 2>&1 && lspci | grep -qi nvidia; then
        local gpu=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -n1 2>/dev/null)
        if [[ "$gpu" =~ ^[0-9]+$ ]]; then
            usage="$gpu"
        fi
    elif command -v rocm-smi &>/dev/null 2>&1; then
        local gpu=$(rocm-smi --showuse 2>/dev/null | grep -o '[0-9]\+%' | head -1 | sed 's/%//')
        if [[ "$gpu" =~ ^[0-9]+$ ]]; then
            usage="$gpu"
        fi
    elif command -v intel_gpu_top &>/dev/null 2>&1; then
        local gpu=$(timeout 1s intel_gpu_top -J 2>/dev/null | jq -r '.engines[0].busy // empty' | grep -o '[0-9]\+%' | head -1 | sed 's/%//')
        if [[ "$gpu" =~ ^[0-9]+$ ]]; then
            usage="$gpu"
        fi
    elif [[ -r /sys/class/drm/card0/device/gpu_busy_percent ]]; then
        usage=$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || echo "0")
    fi

    printf "%s%%" "$usage"
}

get_kblayout() {
    if command -v setxkbmap &> /dev/null; then
        local layout=$(setxkbmap -query 2>/dev/null | grep layout | awk '{print $2}' | cut -c1-2)
        echo "${layout:-us}"
    else
        echo "us"
    fi
}

update_status() {
    local name=$1
    local value=$2
    
    echo "$value" > "$CACHE_DIR/$name.txt"
    
    if check_psp_connected; then
        mkdir -p "$PSP_MOUNT/$HOMEBREW_PATH/assets/statuses" 2>/dev/null
        echo "$value" > "$PSP_MOUNT/$HOMEBREW_PATH/assets/statuses/$name.txt" 2>/dev/null
    fi
}

update_all() {
    update_status "cpu" "$(get_cpu_usage)"
    update_status "ram" "$(get_ram_usage)"
    update_status "gpu" "$(get_gpu_usage)"
    update_status "kblayout" "$(get_kblayout)"
}

start_background() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            zenity --info --text="Фоновый процесс уже запущен (PID: $pid)" --width=300
            return
        fi
    fi
    
    (
        echo "Запуск фонового процесса $$" > "$LOG_FILE"
        echo "$(date): Начало работы" >> "$LOG_FILE"
        
        while true; do
            update_all
            echo "$(date): Обновлено" >> "$LOG_FILE"
            sleep "$UPDATE_INTERVAL"
        done
    ) &
    
    echo $! > "$PID_FILE"
    zenity --info --text="Фоновый процесс запущен\nPID: $!\nИнтервал: ${UPDATE_INTERVAL}с" --width=300
}

stop_background() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            echo "$(date): Остановлен" >> "$LOG_FILE"
            zenity --info --text="Фоновый процесс остановлен" --width=250
        else
            rm -f "$PID_FILE"
            zenity --info --text="Фоновый процесс не найден" --width=250
        fi
    else
        zenity --info --text="Фоновый процесс не запущен" --width=250
    fi
}

settings_menu() {
    while true; do
        choice=$(zenity --list \
            --title="Настройки" \
            --text="Текущие настройки:" \
            --column="Опция" \
            "Путь к PSP: ${PSP_MOUNT:-Не настроен}" \
            "Путь Homebrew: $HOMEBREW_PATH" \
            "Интервал обновления: ${UPDATE_INTERVAL}с" \
            "Фоновый режим: ${AUTO_MODE:-нет}" \
            "Очистить кэш" \
            "Показать логи" \
            "Назад" \
            --width=450 --height=350)
        
        case "$choice" in
            "Путь к PSP: "*)
                new_path=$(zenity --file-selection --directory \
                    --title="Выберите папку PSP" \
                    --filename="$PSP_MOUNT")
                [ -n "$new_path" ] && PSP_MOUNT="$new_path" && save_config
                ;;
            "Путь Homebrew: "*)
                new_path=$(zenity --entry \
                    --title="Путь к Homebrew" \
                    --text="Относительный путь от корня PSP:" \
                    --entry-text="$HOMEBREW_PATH")
                [ -n "$new_path" ] && HOMEBREW_PATH="$new_path" && save_config
                ;;
            "Интервал обновления: "*)
                new_int=$(zenity --scale \
                    --title="Интервал обновления" \
                    --text="Секунды между обновлениями:" \
                    --min-value=1 --max-value=30 --value=$UPDATE_INTERVAL \
                    --step=1)
                [ -n "$new_int" ] && UPDATE_INTERVAL="$new_int" && save_config
                ;;
            "Фоновый режим: "*)
                if [ "$AUTO_MODE" = "true" ]; then
                    AUTO_MODE=false
                    save_config
                    zenity --info --text="Фоновый режим отключен\nСуществующие процессы продолжают работу"
                else
                    AUTO_MODE=true
                    save_config
                    zenity --info --text="Фоновый режим включен\nЗапустите его из главного меню"
                fi
                ;;
            "Очистить кэш")
                if zenity --question --text="Очистить кэш в $CACHE_DIR?"; then
                    rm -rf "$CACHE_DIR"/*
                    mkdir -p "$CACHE_DIR"
                    zenity --info --text="Кэш очищен"
                fi
                ;;
            "Показать логи")
                if [ -f "$LOG_FILE" ]; then
                    zenity --text-info \
                        --title="Логи фонового процесса" \
                        --filename="$LOG_FILE" \
                        --width=600 --height=400
                else
                    zenity --info --text="Лог файл не найден"
                fi
                ;;
            "Назад"|*)
                break
                ;;
        esac
    done
}

show_current_values() {
    local values=""
    for file in "$CACHE_DIR"/*.txt; do
        if [ -f "$file" ]; then
            local name=$(basename "$file" .txt)
            local value=$(cat "$file")
            values="$values$name: $value\n"
        fi
    done
    
    if [ -z "$values" ]; then
        values="Кэш пуст"
    fi
    
    zenity --text-info \
        --title="Текущие значения" \
        --filename=<(echo -e "$values") \
        --width=400 --height=300
}

show_main_menu() {
    load_config
    
    while true; do
        if check_psp_connected; then
            status_info="✓ PSP подключена\nПуть: $PSP_MOUNT"
        else
            status_info="✗ PSP не подключена\nПуть: ${PSP_MOUNT:-Не настроен}"
        fi
        
        bg_status=""
        if [ -f "$PID_FILE" ]; then
            local pid=$(cat "$PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                bg_status="✓ Фоновый процесс запущен (PID: $pid)"
            else
                bg_status="✗ Фоновый процесс неактивен"
                rm -f "$PID_FILE"
            fi
        else
            bg_status="✗ Фоновый процесс не запущен"
        fi
        
        choice=$(zenity --list \
            --title="PSP Widgets Client" \
            --text="$status_info\n$bg_status\n\nВыберите действие:" \
            --column="Меню" \
            "Обновить статусы сейчас" \
            "Запустить в фоне" \
            "Остановить фоновый процесс" \
            "Настройки" \
            "Показать текущие значения" \
            "Выйти" \
            --width=400 --height=350)
        
        case "$choice" in
            "Обновить статусы сейчас")
                update_all
                zenity --info --text="Статусы обновлены\n$(date +'%H:%M:%S')" --width=250
                ;;
            "Запустить в фоне")
                if check_psp_connected || zenity --question --text="PSP не подключена. Запустить только локальное кэширование?" --width=300; then
                    start_background
                fi
                ;;
            "Остановить фоновый процесс")
                stop_background
                ;;
            "Настройки")
                settings_menu
                ;;
            "Показать текущие значения")
                show_current_values
                ;;
            "Выйти"|*)
                stop_background 2>/dev/null
                exit 0
                ;;
        esac
    done
}

check_dependencies() {
    if ! command -v zenity &> /dev/null; then
        echo "Ошибка: zenity не установлен"
        echo "Установите: sudo apt install zenity"
        exit 1
    fi
}

if [ "$1" = "--autostart" ]; then
    load_config
    if [ "$AUTO_MODE" = "true" ]; then
        start_background
    fi
    exit 0
fi

check_dependencies
show_main_menu
