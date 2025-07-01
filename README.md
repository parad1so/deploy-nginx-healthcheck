# Docker мультистейдж сборка для ngx_dynamic_healthcheck

Этот проект добавляет в репозиторий [ngx_dynamic_healthcheck](https://github.com/parad1so/ngx_dynamic_healthcheck) возможность мультистейдж сборки в Docker с полной тестовой средой.

## 🚀 Быстрый старт

```bash
# Клонирование и запуск
git clone https://github.com/parad1so/ngx_dynamic_healthcheck.git
cd ngx_dynamic_healthcheck

# Развертывание всей среды
bash scripts/deploy.sh

# Открыть в браузере
open http://localhost/
```

## 📋 Что включено

### 🐳 Docker компоненты
- **Мультистейдж Dockerfile** - сборка nginx на CentOS с модулем healthcheck
- **docker-compose.yml** - полная тестовая среда с 3 Tomcat серверами
- **nginx.conf** - настроенная конфигурация с примерами healthcheck

### 🛠️ Автоматизация
- **deploy.sh** - автоматическое развертывание всей среды
- **test_healthcheck.sh** - комплексное тестирование функционала
- **manage_services.sh** - управление отдельными сервисами

### 🌐 Тестовые приложения
- 3 различных Tomcat приложения с уникальным дизайном
- Эндпоинты для тестирования healthcheck (`/health`, `/api/status`, `/slow`)
- Визуальная индикация балансировки нагрузки

### 📊 Мониторинг
- Интерфейс статуса healthcheck на `/healthcheck/status`
- JSON API для автоматизации
- Конфигурация Prometheus (опционально)

## 🎯 Основные возможности

### Динамические проверки здоровья
- **HTTP проверки** - с настраиваемыми URI и кодами ответа
- **TCP проверки** - простая проверка доступности портов
- **SSL проверки** - проверка SSL/TLS соединений

### Отказоустойчивость
- Автоматическое исключение неработающих серверов
- Настраиваемые параметры fall/rise
- Балансировка нагрузки между здоровыми серверами

### Управление в реальном времени
- HTTP API для получения статуса
- Динамическая реконфигурация без перезагрузки nginx
- Временное отключение/включение серверов

## 📚 Документация

Подробная документация доступна в файле `Docker_Healthcheck_Documentation.md`.

## 🧪 Тестирование

```bash
# Полное тестирование функционала
bash scripts/test_healthcheck.sh full

# Тестирование балансировки
bash scripts/test_healthcheck.sh balance

# Тестирование отказоустойчивости
bash scripts/test_healthcheck.sh failover

# Мониторинг в реальном времени
bash scripts/test_healthcheck.sh monitor
```

## 🔧 Управление сервисами

```bash
# Статус всех сервисов
bash scripts/manage_services.sh status

# Остановка сервера для тестирования failover
bash scripts/manage_services.sh stop tomcat2

# Запуск сервера обратно
bash scripts/manage_services.sh start tomcat2

# Интерактивное меню
bash scripts/manage_services.sh
```

## 🌍 Веб-интерфейсы

После запуска доступны следующие интерфейсы:

- **Главная страница**: http://localhost/
- **Приложение** (балансировка): http://localhost/app/
- **Статус healthcheck**: http://localhost/healthcheck/status
- **Админ-панель**: http://localhost:8081/status
- **Tomcat серверы**: http://localhost:8080, http://localhost:8082, http://localhost:8083

## 📁 Структура проекта

```
├── Dockerfile                 # Мультистейдж сборка nginx
├── docker-compose.yml         # Композиция сервисов
├── nginx.conf                 # Конфигурация nginx с healthcheck
├── webapps/                   # Тестовые приложения
│   ├── app1/                  # Tomcat Server 1
│   ├── app2/                  # Tomcat Server 2
│   └── app3/                  # Tomcat Server 3
├── scripts/                   # Скрипты автоматизации
│   ├── deploy.sh              # Развертывание
│   ├── test_healthcheck.sh    # Тестирование
│   └── manage_services.sh     # Управление сервисами
├── monitoring/                # Конфигурация мониторинга
│   └── prometheus.yml         # Настройки Prometheus
└── docs/                      # Документация
    └── analysis_report_ru.md  # Анализ проекта
```

## ⚡ Требования

- Docker 20.10+
- Docker Compose 2.0+
- curl (для тестирования)

## 🛡️ Лицензия

Проект использует ту же лицензию, что и оригинальный [ngx_dynamic_healthcheck](https://github.com/parad1so/ngx_dynamic_healthcheck).

## 🤝 Участие в разработке

1. Форкните репозиторий
2. Создайте feature ветку
3. Внесите изменения
4. Протестируйте с помощью предоставленных скриптов
5. Отправьте Pull Request

## 📧 Поддержка

При возникновении проблем:
1. Проверьте раздел "Устранение неполадок" в документации
2. Запустите `bash scripts/test_healthcheck.sh status`
3. Создайте issue с логами и описанием проблемы
