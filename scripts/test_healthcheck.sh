#!/bin/bash

# Скрипт для тестирования функционала dynamic healthcheck

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

test_result() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')] TEST: $1${NC}"
}

# Конфигурация
NGINX_HOST="localhost"
NGINX_PORT="80"
HEALTHCHECK_URL="http://${NGINX_HOST}:${NGINX_PORT}/healthcheck/status"
APP_URL="http://${NGINX_HOST}:${NGINX_PORT}/app/"

# Проверка доступности nginx
check_nginx_availability() {
    log "Проверка доступности nginx..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$NGINX_HOST:$NGINX_PORT" > /dev/null 2>&1; then
            log "✅ Nginx доступен"
            return 0
        fi
        
        warn "Попытка $attempt/$max_attempts: nginx недоступен, ожидание..."
        sleep 2
        ((attempt++))
    done
    
    error "❌ Nginx недоступен после $max_attempts попыток"
    return 1
}

# Получение статуса healthcheck
get_healthcheck_status() {
    log "Получение статуса healthcheck..."
    
    local response
    response=$(curl -s "$HEALTHCHECK_URL" 2>/dev/null || echo "ERROR")
    
    if [ "$response" = "ERROR" ]; then
        error "❌ Не удалось получить статус healthcheck"
        return 1
    fi
    
    echo "$response"
}

# Получение JSON статуса healthcheck
get_healthcheck_json() {
    log "Получение JSON статуса healthcheck..."
    
    local response
    response=$(curl -s "${HEALTHCHECK_URL}?format=json" 2>/dev/null || echo "ERROR")
    
    if [ "$response" = "ERROR" ]; then
        error "❌ Не удалось получить JSON статус"
        return 1
    fi
    
    echo "$response"
}

# Тестирование балансировки нагрузки
test_load_balancing() {
    log "Тестирование балансировки нагрузки..."
    
    local requests=10
    local server_counts=()
    
    info "Отправка $requests запросов к приложению..."
    
    for i in $(seq 1 $requests); do
        local response
        response=$(curl -s "$APP_URL" 2>/dev/null || echo "ERROR")
        
        if [[ "$response" =~ "Tomcat Server 1" ]]; then
            ((server_counts[1]++)) || server_counts[1]=1
        elif [[ "$response" =~ "Tomcat Server 2" ]]; then
            ((server_counts[2]++)) || server_counts[2]=1
        elif [[ "$response" =~ "Tomcat Server 3" ]]; then
            ((server_counts[3]++)) || server_counts[3]=1
        else
            warn "Неизвестный ответ от сервера"
        fi
        
        sleep 0.5
    done
    
    test_result "Результаты балансировки:"
    test_result "  - Tomcat Server 1: ${server_counts[1]:-0} запросов"
    test_result "  - Tomcat Server 2: ${server_counts[2]:-0} запросов"
    test_result "  - Tomcat Server 3: ${server_counts[3]:-0} запросов"
}

# Тестирование отказоустойчивости
test_failover() {
    log "Тестирование отказоустойчивости..."
    
    info "Остановка tomcat2 для проверки failover..."
    docker-compose stop tomcat2
    
    sleep 10
    
    info "Проверка статуса после остановки сервера..."
    get_healthcheck_status
    
    info "Тестирование запросов после остановки сервера..."
    test_load_balancing
    
    info "Запуск tomcat2 обратно..."
    docker-compose start tomcat2
    
    sleep 15
    
    info "Проверка статуса после восстановления сервера..."
    get_healthcheck_status
}

# Тестирование различных эндпоинтов
test_endpoints() {
    log "Тестирование различных эндпоинтов..."
    
    local endpoints=(
        "/"
        "/app/"
        "/healthcheck/status"
        "/tcp/"
    )
    
    for endpoint in "${endpoints[@]}"; do
        info "Тестирование эндпоинта: $endpoint"
        
        local status_code
        status_code=$(curl -s -w "%{http_code}" -o /dev/null "http://${NGINX_HOST}:${NGINX_PORT}${endpoint}")
        
        if [ "$status_code" -eq 200 ]; then
            test_result "  ✅ $endpoint: HTTP $status_code"
        else
            test_result "  ❌ $endpoint: HTTP $status_code"
        fi
    done
}

# Мониторинг healthcheck в реальном времени
monitor_healthcheck() {
    log "Запуск мониторинга healthcheck (нажмите Ctrl+C для остановки)..."
    
    while true; do
        clear
        echo -e "${CYAN}=== МОНИТОРИНГ HEALTHCHECK ===${NC}"
        echo -e "${CYAN}Время: $(date)${NC}"
        echo ""
        
        # Получение статуса
        local status
        status=$(get_healthcheck_status 2>/dev/null || echo "Ошибка получения статуса")
        
        echo -e "${BLUE}Статус healthcheck:${NC}"
        echo "$status"
        echo ""
        
        # Статус контейнеров
        echo -e "${BLUE}Статус контейнеров:${NC}"
        docker-compose ps | grep -E "(nginx-healthcheck|tomcat)"
        echo ""
        
        sleep 5
    done
}

# Показ справки
show_help() {
    echo -e "${BLUE}Использование: $0 [команда]${NC}"
    echo ""
    echo "Команды:"
    echo "  status      - Проверить статус healthcheck"
    echo "  json        - Получить JSON статус"
    echo "  balance     - Тестировать балансировку нагрузки"
    echo "  failover    - Тестировать отказоустойчивость"
    echo "  endpoints   - Тестировать все эндпоинты"
    echo "  monitor     - Мониторинг в реальном времени"
    echo "  full        - Полное тестирование"
    echo "  help        - Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 status"
    echo "  $0 full"
    echo "  $0 monitor"
}

# Полное тестирование
full_test() {
    log "🧪 Запуск полного тестирования healthcheck функционала"
    
    check_nginx_availability || exit 1
    
    echo ""
    get_healthcheck_status
    echo ""
    
    test_endpoints
    echo ""
    
    test_load_balancing
    echo ""
    
    test_failover
    echo ""
    
    log "🎉 Полное тестирование завершено!"
}

# Главная функция
main() {
    case "${1:-full}" in
        "status")
            check_nginx_availability && get_healthcheck_status
            ;;
        "json")
            check_nginx_availability && get_healthcheck_json
            ;;
        "balance")
            check_nginx_availability && test_load_balancing
            ;;
        "failover")
            check_nginx_availability && test_failover
            ;;
        "endpoints")
            check_nginx_availability && test_endpoints
            ;;
        "monitor")
            check_nginx_availability && monitor_healthcheck
            ;;
        "full")
            full_test
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            error "Неизвестная команда: $1"
            show_help
            exit 1
            ;;
    esac
}

# Обработка сигналов
trap 'echo -e "\n${YELLOW}Тестирование прервано${NC}"; exit 0' INT TERM

# Запуск
main "$@"
