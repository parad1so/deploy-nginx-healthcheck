#!/bin/bash

# Скрипт для управления отдельными сервисами

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функции для логирования
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO: $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"
}

# Список сервисов
SERVICES=("nginx-healthcheck" "tomcat1" "tomcat2" "tomcat3")

# Проверка существования сервиса
check_service_exists() {
    local service=$1
    if [[ ! " ${SERVICES[@]} " =~ " ${service} " ]]; then
        error "Сервис '$service' не найден!"
        echo "Доступные сервисы: ${SERVICES[*]}"
        return 1
    fi
}

# Получение статуса сервиса
get_service_status() {
    local service=$1
    local status
    
    status=$(docker-compose ps "$service" --format "table {{.Name}}\t{{.State}}\t{{.Status}}" 2>/dev/null | tail -n +2)
    
    if [ -z "$status" ]; then
        echo "не найден"
    else
        echo "$status"
    fi
}

# Показ статуса всех сервисов
show_all_status() {
    log "Статус всех сервисов:"
    echo ""
    printf "%-20s %-15s %-30s\n" "СЕРВИС" "СОСТОЯНИЕ" "СТАТУС"
    printf "%-20s %-15s %-30s\n" "------" "---------" "------"
    
    for service in "${SERVICES[@]}"; do
        local status
        status=$(get_service_status "$service")
        
        if [[ "$status" =~ "Up" ]]; then
            printf "%-20s ${GREEN}%-15s${NC} %-30s\n" "$service" "Запущен" "$status"
        elif [[ "$status" =~ "Exit" ]]; then
            printf "%-20s ${RED}%-15s${NC} %-30s\n" "$service" "Остановлен" "$status"
        else
            printf "%-20s ${YELLOW}%-15s${NC} %-30s\n" "$service" "Неизвестно" "$status"
        fi
    done
    echo ""
}

# Запуск сервиса
start_service() {
    local service=$1
    check_service_exists "$service" || return 1
    
    log "Запуск сервиса $service..."
    
    if docker-compose ps "$service" | grep -q "Up"; then
        warn "Сервис $service уже запущен"
        return 0
    fi
    
    docker-compose start "$service"
    
    # Ожидание запуска
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        if docker-compose ps "$service" | grep -q "Up"; then
            log "✅ Сервис $service успешно запущен"
            return 0
        fi
        
        sleep 1
        ((attempts++))
    done
    
    error "❌ Не удалось запустить сервис $service"
    return 1
}

# Остановка сервиса
stop_service() {
    local service=$1
    check_service_exists "$service" || return 1
    
    log "Остановка сервиса $service..."
    
    if ! docker-compose ps "$service" | grep -q "Up"; then
        warn "Сервис $service уже остановлен"
        return 0
    fi
    
    docker-compose stop "$service"
    
    # Ожидание остановки
    local attempts=0
    local max_attempts=15
    
    while [ $attempts -lt $max_attempts ]; do
        if ! docker-compose ps "$service" | grep -q "Up"; then
            log "✅ Сервис $service успешно остановлен"
            return 0
        fi
        
        sleep 1
        ((attempts++))
    done
    
    error "❌ Не удалось остановить сервис $service"
    return 1
}

# Перезапуск сервиса
restart_service() {
    local service=$1
    check_service_exists "$service" || return 1
    
    log "Перезапуск сервиса $service..."
    
    stop_service "$service"
    sleep 2
    start_service "$service"
}

# Показ логов сервиса
show_logs() {
    local service=$1
    local follow=${2:-false}
    
    check_service_exists "$service" || return 1
    
    if [ "$follow" = "true" ]; then
        log "Показ логов сервиса $service (следящий режим, Ctrl+C для выхода)..."
        docker-compose logs -f "$service"
    else
        log "Последние логи сервиса $service:"
        docker-compose logs --tail=50 "$service"
    fi
}

# Выполнение команды внутри контейнера
exec_service() {
    local service=$1
    shift
    local command="$*"
    
    check_service_exists "$service" || return 1
    
    if ! docker-compose ps "$service" | grep -q "Up"; then
        error "Сервис $service не запущен"
        return 1
    fi
    
    log "Выполнение команды в $service: $command"
    docker-compose exec "$service" $command
}

# Симуляция нагрузки на сервис
stress_test() {
    local service=$1
    local duration=${2:-30}
    
    check_service_exists "$service" || return 1
    
    log "Запуск нагрузочного тестирования для $service на $duration секунд..."
    
    # Определение порта для тестирования
    local port=""
    case "$service" in
        "nginx-healthcheck") port="80" ;;
        "tomcat1") port="8080" ;;
        "tomcat2") port="8082" ;;
        "tomcat3") port="8083" ;;
    esac
    
    if [ -z "$port" ]; then
        error "Не удалось определить порт для $service"
        return 1
    fi
    
    info "Отправка запросов на localhost:$port в течение $duration секунд..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    local request_count=0
    local success_count=0
    
    while [ $(date +%s) -lt $end_time ]; do
        if curl -s -f "localhost:$port" > /dev/null 2>&1; then
            ((success_count++))
        fi
        ((request_count++))
        
        # Показ прогресса каждые 100 запросов
        if [ $((request_count % 100)) -eq 0 ]; then
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))
            local remaining=$((duration - elapsed))
            info "Прогресс: $request_count запросов, $success_count успешных, осталось ${remaining}с"
        fi
        
        sleep 0.1
    done
    
    log "Нагрузочное тестирование завершено:"
    log "  - Всего запросов: $request_count"
    log "  - Успешных запросов: $success_count"
    log "  - Процент успеха: $(( success_count * 100 / request_count ))%"
}

# Показ справки
show_help() {
    echo -e "${BLUE}Использование: $0 <команда> [аргументы]${NC}"
    echo ""
    echo "Команды управления сервисами:"
    echo "  status                    - Показать статус всех сервисов"
    echo "  start <сервис>           - Запустить сервис"
    echo "  stop <сервис>            - Остановить сервис"
    echo "  restart <сервис>         - Перезапустить сервис"
    echo "  logs <сервис> [follow]   - Показать логи сервиса"
    echo "  exec <сервис> <команда>  - Выполнить команду в контейнере"
    echo "  stress <сервис> [время]  - Нагрузочное тестирование"
    echo ""
    echo "Доступные сервисы: ${SERVICES[*]}"
    echo ""
    echo "Примеры:"
    echo "  $0 status"
    echo "  $0 start tomcat1"
    echo "  $0 stop tomcat2"
    echo "  $0 restart nginx-healthcheck"
    echo "  $0 logs tomcat1 follow"
    echo "  $0 exec nginx-healthcheck nginx -t"
    echo "  $0 stress tomcat1 60"
}

# Интерактивное меню
interactive_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== УПРАВЛЕНИЕ СЕРВИСАМИ ===${NC}"
        echo ""
        show_all_status
        
        echo "Выберите действие:"
        echo "1) Запустить сервис"
        echo "2) Остановить сервис"
        echo "3) Перезапустить сервис"
        echo "4) Показать логи"
        echo "5) Нагрузочное тестирование"
        echo "6) Обновить статус"
        echo "0) Выход"
        echo ""
        
        read -p "Введите номер действия: " choice
        
        case $choice in
            1)
                echo "Доступные сервисы: ${SERVICES[*]}"
                read -p "Введите имя сервиса для запуска: " service
                start_service "$service"
                ;;
            2)
                echo "Доступные сервисы: ${SERVICES[*]}"
                read -p "Введите имя сервиса для остановки: " service
                stop_service "$service"
                ;;
            3)
                echo "Доступные сервисы: ${SERVICES[*]}"
                read -p "Введите имя сервиса для перезапуска: " service
                restart_service "$service"
                ;;
            4)
                echo "Доступные сервисы: ${SERVICES[*]}"
                read -p "Введите имя сервиса для просмотра логов: " service
                show_logs "$service"
                ;;
            5)
                echo "Доступные сервисы: ${SERVICES[*]}"
                read -p "Введите имя сервиса для нагрузочного тестирования: " service
                read -p "Введите длительность в секундах (по умолчанию 30): " duration
                duration=${duration:-30}
                stress_test "$service" "$duration"
                ;;
            6)
                continue
                ;;
            0)
                log "Выход..."
                exit 0
                ;;
            *)
                error "Неверный выбор: $choice"
                ;;
        esac
        
        echo ""
        read -p "Нажмите Enter для продолжения..."
    done
}

# Главная функция
main() {
    case "${1:-}" in
        "status")
            show_all_status
            ;;
        "start")
            if [ -z "$2" ]; then
                error "Не указан сервис для запуска"
                show_help
                exit 1
            fi
            start_service "$2"
            ;;
        "stop")
            if [ -z "$2" ]; then
                error "Не указан сервис для остановки"
                show_help
                exit 1
            fi
            stop_service "$2"
            ;;
        "restart")
            if [ -z "$2" ]; then
                error "Не указан сервис для перезапуска"
                show_help
                exit 1
            fi
            restart_service "$2"
            ;;
        "logs")
            if [ -z "$2" ]; then
                error "Не указан сервис для просмотра логов"
                show_help
                exit 1
            fi
            show_logs "$2" "$3"
            ;;
        "exec")
            if [ -z "$2" ]; then
                error "Не указан сервис для выполнения команды"
                show_help
                exit 1
            fi
            shift 2
            exec_service "$2" "$@"
            ;;
        "stress")
            if [ -z "$2" ]; then
                error "Не указан сервис для нагрузочного тестирования"
                show_help
                exit 1
            fi
            stress_test "$2" "$3"
            ;;
        "menu")
            interactive_menu
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        "")
            interactive_menu
            ;;
        *)
            error "Неизвестная команда: $1"
            show_help
            exit 1
            ;;
    esac
}

# Обработка сигналов
trap 'echo -e "\n${YELLOW}Операция прервана${NC}"; exit 0' INT TERM

# Запуск
main "$@"
