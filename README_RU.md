# widgets_portable-client

### [english readme version / английская версия readme](./README.md)

Клиент для ПК для **widgets_portable**

## Версии

* **Linux** готово, доступно в `linux/client.sh`
* **Windows** не готово
* **macOS** не готово

## Установка

### Linux

1. Установите пакет **zenity** через менеджер пакетов вашей системы

   * Для Arch-подобных: `sudo pacman -S zenity`
   * Для Debian-подобных: `sudo apt install zenity`
2. Скачайте `client.sh` из папки `linux/`
3. Сделайте его исполняемым:

   ```bash
   chmod +x client.sh
   ```
4. Запустите установщик:

   ```bash
   ./client.sh --install
   ```
5. Готово! Теперь приложение можно запускать через любой лаунчер (например, Rofi, Wofi и т.д.)
