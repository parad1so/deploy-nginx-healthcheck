#!/bin/bash

# Скрипт для развертывания nginx с модулем healthcheck и тестовой среды

set -e

echo "🚀 Развертывание nginx с модулем dynamic healthcheck..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для логирования
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Проверка зависимостей
check_dependencies() {
    log "Проверка зависимостей..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker не установлен!"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose не установлен!"
        exit 1
    fi
    
    log "✅ Все зависимости установлены"
}

# Остановка существующих контейнеров
cleanup() {
    log "Остановка существующих контейнеров..."
    docker-compose down --remove-orphans || true
    docker system prune -f --volumes || true
}

# Сборка образов
build_images() {
    log "Сборка Docker образов..."
    docker-compose build --no-cache
}

# Запуск сервисов
start_services() {
    log "Запуск сервисов..."
    
    # Запуск основных сервисов
    docker-compose up -d nginx-healthcheck tomcat1 tomcat2
    
    # Ожидание готовности сервисов
    log "Ожидание готовности сервисов..."
    sleep 30
    
    # Проверка статуса
    check_services_status
}

# Проверка статуса сервисов
check_services_status() {
    log "Проверка статуса сервисов..."
    
    local services=("nginx-healthcheck" "tomcat1" "tomcat2")
    local all_healthy=true
    
    for service in "${services[@]}"; do
        if docker-compose ps "$service" | grep -q "Up"; then
            echo -e "  ✅ $service: ${GREEN}Запущен${NC}"
        else
            echo -e "  ❌ $service: ${RED}Не запущен${NC}"
            all_healthy=false
        fi
    done
    
    if [ "$all_healthy" = true ]; then
        log "Все основные сервисы запущены успешно!"
    else
        warn "Некоторые сервисы не запустились"
    fi
}

# Показ информации о развертывании
show_deployment_info() {
    log "Информация о развертывании:"
    echo ""
    echo -e "${BLUE}🌐 Веб-интерфейсы:${NC}"
    echo "  - Главная страница nginx:     http://localhost/"
    echo "  - Приложение (балансировка):  http://localhost/app/"
    echo "  - Статус healthcheck:         http://localhost/healthcheck/status"
    echo "  - Админ-панель healthcheck:   http://localhost:8081/status"
    echo ""
    echo -e "${BLUE}🖥️ Tomcat серверы:${NC}"
    echo "  - Tomcat 1 (прямой доступ):   http://localhost:8080/"
    echo "  - Tomcat 2 (прямой доступ):   http://localhost:8082/"
    echo ""
    echo -e "${BLUE}📊 Мониторинг:${NC}"
    echo "  - Логи nginx:                 docker-compose logs -f nginx-healthcheck"
    echo "  - Статус контейнеров:         docker-compose ps"
    echo ""
    echo -e "${BLUE}🔧 Управление:${NC}"
    echo "  - Запуск всех сервисов:       ./scripts/deploy.sh"
    echo "  - Тестирование healthcheck:   ./scripts/test_healthcheck.sh"
    echo "  - Остановка всех сервисов:    docker-compose down"
    echo ""
}

# Главная функция
main() {
    log "Начало развертывания nginx с модулем dynamic healthcheck"
    
    check_dependencies
    cleanup
    build_images
    start_services
    show_deployment_info
    
    log "🎉 Развертывание завершено успешно!"
    log "Откройте http://localhost/ в браузере для тестирования"
}

# Обработка аргументов командной строки
case "${1:-}" in
    "cleanup")
        cleanup
        ;;
    "build")
        build_images
        ;;
    "start")
        start_services
        ;;
    "status")
        check_services_status
        ;;
    "info")
        show_deployment_info
        ;;
    *)
        main
        ;;
esac
