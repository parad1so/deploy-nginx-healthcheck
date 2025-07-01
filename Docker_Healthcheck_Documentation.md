
# Документация по Docker-инфраструктуре для nginx с модулем ngx_dynamic_healthcheck

## Оглавление
1.  [Введение и обзор](#1-введение-и-обзор)
2.  [Архитектура решения](#2-архитектура-решения)
    -   [Мультистейдж Docker-сборка](#мультистейдж-docker-сборка)
    -   [Композиция сервисов](#композиция-сервисов)
3.  [Быстрый старт](#3-быстрый-старт)
4.  [Подробное описание компонентов](#4-подробное-описание-компонентов)
    -   [Dockerfile](#dockerfile)
    -   [docker-compose.yml](#docker-composeyml)
    -   [nginx.conf](#nginxconf)
    -   [Тестовые веб-приложения](#тестовые-веб-приложения)
5.  [Использование скриптов автоматизации](#5-использование-скриптов-автоматизации)
    -   [deploy.sh](#deploysh)
    -   [test_healthcheck.sh](#test_healthchecksh)
    -   [manage_services.sh](#manage_servicesh)
6.  [Тестирование и проверка работы](#6-тестирование-и-проверка-работы)
7.  [Управление и мониторинг](#7-управление-и-мониторинг)
    -   [Управление сервисами](#управление-сервисами)
    -   [Мониторинг с Prometheus](#мониторинг-с-prometheus)
8.  [Примеры использования](#8-примеры-использования)
9.  [Устранение неполадок](#9-устранение-неполадок)
10. [Расширение и кастомизация](#10-расширение-и-кастомизация)

---

## 1. Введение и обзор

Этот проект предоставляет готовую к использованию Docker-инфраструктуру для сборки и запуска **Nginx** с динамическим модулем **ngx_dynamic_healthcheck**. Модуль позволяет на лету проверять состояние upstream-серверов, динамически исключая из балансировки неработающие инстансы без перезагрузки Nginx.

**Ключевые цели проекта:**
-   **Автоматизация сборки**: Предоставить `Dockerfile` для автоматической компиляции Nginx с кастомным модулем.
-   **Готовая среда**: Создать `docker-compose.yml` для быстрого развертывания Nginx вместе с набором тестовых бэкенд-сервисов (Tomcat).
-   **Демонстрация работы**: Показать на реальных примерах, как настраивать и использовать модуль `ngx_dynamic_healthcheck`.
-   **Упрощение разработки и тестирования**: Дать разработчикам инструмент для локального тестирования сложных конфигураций балансировки нагрузки.

Эта документация предназначена для разработчиков и DevOps-инженеров, которым необходимо развернуть и кастомизировать данное решение.

## 2. Архитектура решения

Решение построено на принципах изоляции и переиспользования компонентов с помощью Docker. Архитектура состоит из двух основных частей: процесса сборки Nginx и композиции runtime-сервисов.

### Мультистейдж Docker-сборка

Для создания production-ready образа Nginx используется многостадийная сборка (`Dockerfile`), что позволяет значительно уменьшить размер финального образа и повысить его безопасность.

-   **Build Stage (`builder`)**:
    -   **Базовый образ**: `centos:7`.
    -   **Назначение**: Собрать Nginx из исходных кодов вместе с модулями `ngx_dynamic_healthcheck` и его зависимостью `ngx_dynamic_upstream`.
    -   **Процесс**: В этой стадии устанавливаются все необходимые для компиляции зависимости (`gcc`, `g++`, `make`, `pcre-devel`, `zlib-devel`, `openssl-devel`), клонируются репозитории модулей и исходные коды Nginx, после чего происходит компиляция.
    -   **Результат**: Готовый бинарный файл Nginx и все необходимые модули.

-   **Final Stage (`final`)**:
    -   **Базовый образ**: `nginx:1.24.0-alpine`.
    -   **Назначение**: Создать легковесный и безопасный образ для production.
    -   **Процесс**: На этой стадии копируются только скомпилированные артефакты из `builder`-стейджа (бинарник Nginx, модули). Никаких сборочных зависимостей и исходных кодов в финальном образе нет.

### Композиция сервисов

Окружение для тестирования и демонстрации описывается в файле `docker-compose.yml` и включает в себя следующие сервисы:

-   **`nginx-healthcheck`**: Фронтенд-сервер Nginx, собранный с помощью нашего `Dockerfile`. Он принимает трафик и распределяет его между бэкенд-сервисами.
-   **`tomcat-app1`, `tomcat-app2`, `tomcat-app3`**: Три идентичных бэкенд-сервиса на базе образа `tomcat:9.0-jdk11-corretto`. Каждый из них содержит простое веб-приложение для демонстрации работы health-чеков.
-   **`prometheus`**: Сервис для сбора метрик. Хотя в базовой конфигурации Nginx не отдает метрики в формате Prometheus, он настроен для демонстрации возможностей мониторинга.
-   **Сеть `nginx-net`**: Все сервисы объединены в одну Docker-сеть для удобного взаимодействия.

![Architecture](https://i.imgur.com/example.png) *(Примечание: диаграмму следует создать и вставить)*

## 3. Быстрый старт

Для развертывания всей инфраструктуры локально выполните следующие шаги:

1.  **Клонируйте репозиторий** (если еще не сделали):
    ```bash
    git clone https://github.com/parad1so/ngx_dynamic_healthcheck.git
    cd ngx_dynamic_healthcheck
    ```

2.  **Запустите скрипт развертывания**:
    Этот скрипт выполнит сборку образа и запустит все сервисы.
    ```bash
    sudo ./scripts/deploy.sh
    ```

3.  **Проверьте работу**: 
    -   Откройте в браузере `http://localhost:8080`. При каждом обновлении страницы вы должны видеть приветствие от одного из трех Tomcat-серверов (`app1`, `app2` или `app3`).
    -   Выполните скрипт для проверки статуса health-чеков:
        ```bash
        ./scripts/test_healthcheck.sh
        ```

4.  **Остановка окружения**:
    ```bash
    sudo docker-compose down
    ```

## 4. Подробное описание компонентов

### Dockerfile

`Dockerfile` использует мультистейдж-подход для оптимизации.

**Сборочный стейдж (`builder`)**
```dockerfile
FROM centos:7 AS builder

# Установка сборочных зависимостей
RUN yum install -y gcc gcc-c++ make pcre-devel zlib-devel openssl-devel git wget

WORKDIR /build

# Клонирование модулей и скачивание Nginx
RUN git clone https://github.com/ZigzagAK/ngx_dynamic_upstream.git && \
    git clone https://github.com/parad1so/ngx_dynamic_healthcheck.git && \
    wget http://nginx.org/download/nginx-1.24.0.tar.gz && \
    tar -xzf nginx-1.24.0.tar.gz

# Сборка Nginx
WORKDIR /build/nginx-1.24.0
RUN ./configure \
    --add-module=/build/ngx_dynamic_upstream \
    --add-module=/build/ngx_dynamic_healthcheck \
    --with-stream \
    && make && make install
```

**Финальный стейдж (`final`)**
```dockerfile
FROM nginx:1.24.0-alpine AS final

# Копирование скомпилированного Nginx из builder-стейджа
COPY --from=builder /usr/local/nginx/sbin/nginx /usr/sbin/nginx

# Опционально: копирование модулей, если они собирались как динамические
# COPY --from=builder /usr/local/nginx/modules/*.so /etc/nginx/modules/

# Копирование кастомной конфигурации
COPY nginx.conf /etc/nginx/nginx.conf
```

### docker-compose.yml

Файл `docker-compose.yml` оркестрирует запуск всех компонентов системы.

```yaml
version: '3.8'

services:
  nginx-healthcheck:
    build: .
    container_name: nginx-healthcheck
    ports:
      - "8080:80"       # Основной порт Nginx
      - "8888:8888"     # Порт для API модуля healthcheck
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    networks:
      - nginx-net

  tomcat-app1:
    image: tomcat:9.0-jdk11-corretto
    container_name: tomcat-app1
    volumes:
      - ./webapps/app1:/usr/local/tomcat/webapps/ROOT
    networks:
      - nginx-net

  # ... аналогичные секции для tomcat-app2 и tomcat-app3 ...

  prometheus:
    image: prom/prometheus:v2.37.0
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - nginx-net

networks:
  nginx-net:
    driver: bridge
```

### nginx.conf

Это сердце конфигурации. Здесь настраивается балансировка и сами health-чеки.

-   **HTTP-блок**: Определяет глобальные параметры для health-чеков и API.
-   **Upstream-блоки**: Каждый `upstream` определяет группу серверов. **Важно:** для работы модуля каждый upstream должен иметь директиву `zone`.

```nginx
worker_processes 1;

events { worker_connections 1024; }

http {
    # Глобальные настройки health-чеков (можно переопределить в upstream)
    healthcheck fall=2 rise=2 interval=5 timeout=1000 type=http;

    # API для управления health-чеками
    server {
        listen 8888;
        location = /healthcheck/status {
            healthcheck_status;
        }
        location = /healthcheck/update {
            healthcheck_update;
        }
    }

    # Upstream для стандартной проверки по HTTP
    upstream tomcat_backend {
        zone tomcat_backend_zone 64k;
        server tomcat-app1:8080;
        server tomcat-app2:8080;
        server tomcat-app3:8080;

        check fall=2 rise=2 interval=3 timeout=1000 type=http;
        check_request_uri GET /health.html;
        check_response_codes 200;
    }

    server {
        listen 80;
        location / {
            proxy_pass http://tomcat_backend;
            proxy_set_header Host $host;
        }
    }
}
```

### Тестовые веб-приложения

В директории `webapps` находятся три папки (`app1`, `app2`, `app3`), каждая из которых представляет собой простое веб-приложение. Они содержат:
-   `index.html`: Главная страница, отображающая имя сервера (`Welcome to app1!`).
-   `health.html`: Страница для успешных health-чеков, всегда возвращает код `200 OK`.
-   `slow.html`: Страница для тестирования таймаутов (искусственно замедлена).

## 5. Использование скриптов автоматизации

### deploy.sh

Скрипт для полного развертывания стека.
-   **Что делает**: Собирает Docker-образ `nginx-healthcheck` и запускает все сервисы с помощью `docker-compose up -d`.
-   **Использование**: `sudo ./scripts/deploy.sh`

### test_healthcheck.sh

Скрипт для демонстрации работы API модуля.
-   **Что делает**: Отправляет `curl`-запрос к API-ендпоинту `http://localhost:8888/healthcheck/status` и выводит текущий статус всех бэкендов в формате JSON. Использует `jq` для форматирования вывода.
-   **Использование**: `./scripts/test_healthcheck.sh`

### manage_services.sh

Утилита для управления отдельными сервисами в `docker-compose`.
-   **Что делает**: Позволяет выполнять команды `start`, `stop`, `restart`, `logs`, `status` для указанного сервиса.
-   **Использование**:
    ```bash
    # Остановить первый Tomcat-сервер
    ./scripts/manage_services.sh stop tomcat-app1

    # Посмотреть логи Nginx
    ./scripts/manage_services.sh logs nginx-healthcheck
    ```

## 6. Тестирование и проверка работы

Проведите следующий сценарий для проверки функциональности:

1.  **Разверните среду**, как указано в разделе "Быстрый старт".

2.  **Проверьте начальный статус**: Выполните `./scripts/test_healthcheck.sh`. Все три сервера `tomcat-app*` должны быть в состоянии `up` (`"down":0`).

3.  **Имитируйте сбой**: Остановите один из контейнеров Tomcat.
    ```bash
    docker stop tomcat-app2
    ```

4.  **Проверьте изменение статуса**: Подождите несколько секунд (согласно `interval` в `nginx.conf`) и снова выполните `./scripts/test_healthcheck.sh`. Теперь `tomcat-app2` должен быть в состоянии `down` (`"down":1`).

5.  **Проверьте балансировку**: Обновите страницу `http://localhost:8080` несколько раз. Вы увидите, что трафик теперь распределяется только между `app1` и `app3`.

6.  **Восстановите сервис**: Запустите остановленный контейнер.
    ```bash
    docker start tomcat-app2
    ```

7.  **Проверьте восстановление**: Через некоторое время health-чек снова определит сервис как работающий, и он вернется в ротацию.

## 7. Управление и мониторинг

### Управление сервисами

Используйте `docker-compose` или скрипт `manage_services.sh` для управления жизненным циклом контейнеров.

-   **Просмотр статуса всех контейнеров**: `sudo docker-compose ps`
-   **Просмотр логов**: `sudo docker-compose logs -f <имя_сервиса>`
-   **Перезапуск сервиса**: `sudo docker-compose restart <имя_сервиса>`

### Мониторинг с Prometheus

Prometheus настроен для сбора метрик, но требует, чтобы цели (targets) эти метрики предоставляли. В данной конфигурации Nginx не экспортирует метрики. Для полноценного мониторинга Nginx рекомендуется:

1.  **Включить `ngx_http_stub_status_module`**: Это встроенный модуль Nginx, который предоставляет базовые метрики.
    -   Добавьте `--with-http_stub_status_module` в `Dockerfile`.
    -   Добавьте в `nginx.conf`:
        ```nginx
        server {
            listen 8081;
            location /nginx_status {
                stub_status;
            }
        }
        ```
2.  **Использовать сторонний экспортер**, например, [nginx-prometheus-exporter](https://github.com/nginxinc/nginx-prometheus-exporter).

После настройки вы сможете зайти на `http://localhost:9090` и выполнять запросы к метрикам Nginx.

## 8. Примеры использования

Модуль `ngx_dynamic_healthcheck` очень гибкий. Вот несколько сценариев:

-   **TCP-проверка**: Для сервисов, работающих не по HTTP (например, базы данных).
    ```nginx
    upstream database {
        zone database_zone 64k;
        server db1.example.com:5432;
        check type=tcp;
    }
    ```

-   **Проверка ответа**: Можно проверять не только код ответа, но и содержимое тела с помощью регулярных выражений.
    ```nginx
    check_response_body '.*"status":"OK".*';
    ```

-   **Динамическое отключение сервера через API**: 
    ```bash
    curl -X POST "http://localhost:8888/healthcheck/update?upstream=tomcat_backend&disable_host=tomcat-app3:8080"
    ```
    Эта команда немедленно и перманентно (до обратной команды) выведет `tomcat-app3` из балансировки.

## 9. Устранение неполадок

-   **Контейнер `nginx-healthcheck` не запускается**
    -   **Проблема**: Ошибка в `nginx.conf`.
    -   **Решение**: Проверьте синтаксис конфигурации: `sudo docker-compose exec nginx-healthcheck nginx -t`. Изучите логи: `sudo docker-compose logs nginx-healthcheck`.

-   **Health-чеки не работают (все серверы `down`)**
    -   **Проблема**: Nginx не может достучаться до бэкендов.
    -   **Решение**: Убедитесь, что все контейнеры находятся в одной сети (`nginx-net`). Проверьте, что в `upstream` указаны правильные имена сервисов и порты (например, `tomcat-app1:8080`). Проверьте, что в `upstream` есть директива `zone`.

-   **Сборка в `Dockerfile` завершается с ошибкой**
    -   **Проблема**: Нет доступа к репозиториям `git` или `wget` не может скачать архивы.
    -   **Решение**: Проверьте сетевое подключение. Иногда репозитории могут быть временно недоступны.

## 10. Расширение и кастомизация

-   **Добавление нового бэкенда**:
    1.  Добавьте новый сервис в `docker-compose.yml` по аналогии с `tomcat-app*`.
    2.  Добавьте `server <имя_нового_сервиса>:<порт>;` в соответствующий `upstream` в `nginx.conf`.
    3.  Перезапустите композицию: `sudo docker-compose up -d --no-deps <имя_нового_сервиса> nginx-healthcheck`

-   **Изменение версии Nginx**:
    1.  В `Dockerfile` измените версию Nginx в команде `wget` и в базовом образе финального стейджа (`FROM nginx:...`).

-   **Кастомизация параметров сборки Nginx**:
    -   Добавьте нужные флаги в команду `./configure` в `Dockerfile` (например, `--with-http_ssl_module` для поддержки SSL).

