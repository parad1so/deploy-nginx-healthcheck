# Мультистейдж сборка nginx с модулем ngx_dynamic_healthcheck
# Первый стейдж: сборка на CentOS
FROM centos:7 AS builder

# Фикс репозиториев CentOS 7
RUN sed -i \
    -e 's/mirror.centos.org/vault.centos.org/g' \
    -e 's/^#.*baseurl=http/baseurl=http/g' \
    -e 's/^mirrorlist=http/#mirrorlist=http/g' \
    /etc/yum.repos.d/CentOS-*.repo && \
    yum clean all
    
# Установка зависимостей для сборки
RUN yum update -y && \
    yum groupinstall -y "Development Tools" && \
    yum install -y \
        gcc \
        gcc-c++ \
        make \
        pcre-devel \
        zlib-devel \
        openssl-devel \
        git \
        wget \
        curl

# Создание рабочей директории
WORKDIR /build

# Клонирование репозитория ngx_dynamic_healthcheck
RUN git clone https://github.com/parad1so/ngx_dynamic_healthcheck.git

# Переход в директорию проекта
WORKDIR /build/ngx_dynamic_healthcheck

# Сборка nginx с модулем healthcheck
RUN chmod +x build.sh && ./build.sh

# Проверка успешности сборки
#RUN ls -la nginx-1.24.0/ && \
#    ls -la nginx-1.24.0/sbin

# Второй стейдж: production образ
FROM centos:7

# Фикс репозиториев CentOS 7
RUN sed -i \
    -e 's/mirror.centos.org/vault.centos.org/g' \
    -e 's/^#.*baseurl=http/baseurl=http/g' \
    -e 's/^mirrorlist=http/#mirrorlist=http/g' \
    /etc/yum.repos.d/CentOS-*.repo && \
    yum clean all

# Установка минимальных runtime зависимостей
RUN yum update -y && \
    yum install -y \
        pcre \
        zlib \
        openssl \
        shadow-utils && \
    yum clean all

# Create target directory
RUN mkdir -p /store/nginx

# Copy and extract build
COPY --from=builder /build/ngx_dynamic_healthcheck/install/nginx-*.tar.gz /tmp/
WORKDIR /store/nginx
RUN tar -xzf /tmp/nginx-*.tar.gz -C /store/nginx --strip-components=1

# Rename binary
RUN mv sbin/nginx.debug sbin/nginx

#logs
RUN touch logs/error.log

# Create symlinks for compatibility
RUN ln -sf /store/nginx/sbin/nginx /usr/sbin/nginx && \
    ln -sf /store/nginx/conf /etc/nginx

# Create user and set permissions
RUN groupadd -r nginx && \
    useradd -r -g nginx -s /sbin/nologin -M nginx && \
    chown -R nginx:nginx /store/nginx

# Config example (create nginx.conf in project root)
COPY nginx.conf /store/nginx/conf/

# Expose ports
EXPOSE 80 443

# Command
#CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
CMD ["sh", "-c", "/store/nginx/start.sh && tail -f /dev/null"]
#CMD ["sh", "-c", "ls && tail -f /dev/null"]
