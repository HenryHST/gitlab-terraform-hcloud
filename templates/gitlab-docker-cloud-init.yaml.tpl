#cloud-config
# GitLab CE + Traefik via Docker Compose under /opt/gitlab (Debian host).
write_files:
  - path: /opt/gitlab/traefik/traefik.yml
    owner: root:root
    permissions: "0644"
    content: |
      entryPoints:
        web:
          address: ":80"
        websecure:
          address: ":443"
        traefik:
          address: ":8080"
      ping:
        entryPoint: traefik
      providers:
        docker:
          endpoint: "unix:///var/run/docker.sock"
          exposedByDefault: false
        file:
          directory: /etc/traefik/dynamic_conf
          watch: true
      api:
        dashboard: false
%{ if acme_enabled ~}
      certificatesResolvers:
        letsencrypt:
          acme:
            email: "${acme_email}"
            storage: /letsencrypt/acme.json
            httpChallenge:
              entryPoint: web
%{ endif ~}

  - path: /opt/gitlab/traefik/.env
    owner: root:root
    permissions: "0600"
    content: |
      # Optional: SERVICES_TRAEFIK_* overrides (see docker-compose Traefik service)

  - path: /opt/gitlab/traefik/dynamic_conf/.gitkeep
    owner: root:root
    permissions: "0644"
    content: "#\n"
%{ if renovate_enabled ~}
  - path: /opt/gitlab/renovate/mend-renovate.env
    owner: root:root
    permissions: "0600"
    content: |
      MEND_RNV_LICENSE_KEY=${renovate_license_key}
      MEND_RNV_ACCEPT_TOS=Y
      MEND_RNV_SERVER_API_SECRET=${renovate_server_api_secret}
      MEND_RNV_ADMIN_API_ENABLED=true
      MEND_RNV_REPORTING_ENABLED=true
      MEND_RNV_WEBHOOK_URL=${external_url_scheme}://${renovate_fqdn}/webhook

  - path: /opt/gitlab/renovate/gitlab.env
    owner: root:root
    permissions: "0600"
    content: |
      MEND_RNV_PLATFORM=gitlab
      MEND_RNV_ENDPOINT=${gitlab_api_v4_endpoint}
      MEND_RNV_GITLAB_PAT=${renovate_gitlab_pat}
      MEND_RNV_WEBHOOK_SECRET=${renovate_webhook_secret}
%{ endif ~}

  - path: /opt/gitlab/docker-compose.yml
    owner: root:root
    permissions: "0644"
    content: |
      services:
        traefik:
          container_name: $${SERVICES_TRAEFIK_CONTAINER_NAME:-traefik}
          env_file:
            - ./traefik/.env
          hostname: $${SERVICES_TRAEFIK_HOSTNAME:-traefik}
          healthcheck:
            test: ["CMD", "traefik", "healthcheck", "--ping"]
            timeout: 1s
            interval: 10s
            retries: 3
            start_period: 10s
          image: ${traefik_image}
          networks:
            crowdsec:
              ipv4_address: $${SERVICES_TRAEFIK_NETWORKS_CROWDSEC_IPV4:-172.31.127.253}
              ipv6_address: $${SERVICES_TRAEFIK_NETWORKS_CROWDSEC_IPV6:-fd00:1:be:a:7001:0:3e:6ffe}
            proxy:
              ipv4_address: $${SERVICES_TRAEFIK_NETWORKS_PROXY_IPV4:-172.31.191.247}
              ipv6_address: $${SERVICES_TRAEFIK_NETWORKS_PROXY_IPV6:-fd00:1:be:a:7001:0:3e:7fff}
            socket_proxy:
              ipv4_address: $${SERVICES_TRAEFIK_NETWORKS_SOCKET_PROXY_IPV4:-172.31.255.253}
              ipv6_address: $${SERVICES_TRAEFIK_NETWORKS_SOCKET_PROXY_IPV6:-fd00:1:be:a:7001:0:3e:8ffe}
          ports:
            - "80:80"
            - "8080:8080"
            - "443:443"
          restart: unless-stopped
          security_opt:
            - no-new-privileges:true
          volumes:
            - /etc/localtime:/etc/localtime:ro
            - /var/run/docker.sock:/var/run/docker.sock:ro
            - ./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
            - ./traefik/dynamic_conf:/etc/traefik/dynamic_conf:ro
            - traefik_acme:/letsencrypt
            - traefik_logs:/var/log/traefik
          command:
            - "--configFile=/etc/traefik/traefik.yml"

        postgres:
          image: ${postgres_image}
          restart: unless-stopped
          environment:
            POSTGRES_USER: gitlab
            POSTGRES_PASSWORD: "${postgres_password}"
            POSTGRES_DB: gitlabhq_production
          volumes:
            - "postgres_data:/var/lib/postgresql/data"
          networks:
            - proxy
          healthcheck:
            test: ["CMD-SHELL", "pg_isready -U gitlab -d gitlabhq_production"]
            interval: 5s
            timeout: 5s
            retries: 20

        gitlab:
          image: ${gitlab_ce_image}
          restart: unless-stopped
          hostname: "${gitlab_fqdn}"
          shm_size: "256m"
          depends_on:
            postgres:
              condition: service_healthy
          environment:
            GITLAB_ROOT_PASSWORD: "${gitlab_root_password}"
            GITLAB_OMNIBUS_CONFIG: |
              external_url '${external_url_scheme}://${gitlab_fqdn}'
              nginx['listen_port'] = 80
              nginx['listen_https'] = false
              postgresql['enable'] = false
              gitlab_rails['db_adapter'] = 'postgresql'
              gitlab_rails['db_encoding'] = 'unicode'
              gitlab_rails['db_host'] = 'postgres'
              gitlab_rails['db_port'] = 5432
              gitlab_rails['db_username'] = 'gitlab'
              gitlab_rails['db_password'] = '${postgres_password}'
              gitlab_rails['db_database'] = 'gitlabhq_production'
          volumes:
            - "gitlab_config:/etc/gitlab"
            - "gitlab_logs:/var/log/gitlab"
            - "gitlab_data:/var/opt/gitlab"
          networks:
            - proxy
          labels:
            - "traefik.enable=true"
            - "traefik.docker.network=$${NETWORKS_PROXY_NAME:-proxy}"
            - "traefik.http.services.gitlab.loadbalancer.server.port=80"
%{ if acme_enabled ~}
            - "traefik.http.routers.gitlab.rule=Host(`${gitlab_fqdn}`)"
            - "traefik.http.routers.gitlab.entrypoints=websecure"
            - "traefik.http.routers.gitlab.tls=true"
            - "traefik.http.routers.gitlab.tls.certresolver=letsencrypt"
%{ else ~}
            - "traefik.http.routers.gitlab.rule=Host(`${gitlab_fqdn}`)"
            - "traefik.http.routers.gitlab.entrypoints=web"
%{ endif ~}
%{ if renovate_enabled ~}

        renovate-ce:
          container_name: $${SERVICES_RENOVATE_CONTAINER_NAME:-renovate-ce}
          image: ${renovate_ce_image}
          restart: unless-stopped
          env_file:
            - ./renovate/mend-renovate.env
            - ./renovate/gitlab.env
          environment:
            LOG_LEVEL: info
            MEND_RNV_REQUEST_LOGGER_ENABLED: "false"
            MEND_RNV_LOG_HISTORY_DIR: /logs
            MEND_RNV_SQLITE_FILE_PATH: /db/renovate-db.sqlite
            RENOVATE_REPOSITORY_CACHE: enabled
          volumes:
            - renovate_logs:/logs
            - renovate_db:/db
            - /etc/localtime:/etc/localtime:ro
          networks:
            - proxy
          labels:
            - "traefik.enable=true"
            - "traefik.docker.network=$${NETWORKS_PROXY_NAME:-proxy}"
            - "traefik.http.services.renovate.loadbalancer.server.port=8080"
%{ if acme_enabled ~}
            - "traefik.http.routers.renovate.rule=Host(`${renovate_fqdn}`)"
            - "traefik.http.routers.renovate.entrypoints=websecure"
            - "traefik.http.routers.renovate.tls=true"
            - "traefik.http.routers.renovate.tls.certresolver=letsencrypt"
%{ else ~}
            - "traefik.http.routers.renovate.rule=Host(`${renovate_fqdn}`)"
            - "traefik.http.routers.renovate.entrypoints=web"
%{ endif ~}
%{ endif ~}

      networks:
        crowdsec:
          name: $${NETWORKS_CROWDSEC_NAME:-crowdsec}
          driver: bridge
          enable_ipv6: true
          ipam:
            driver: default
            config:
              - subnet: $${NETWORKS_CROWDSEC_SUBNET_IPV4:-172.31.64.0/18}
              - subnet: $${NETWORKS_CROWDSEC_SUBNET_IPV6:-fd00:1:be:a:7001:0:3e:6000/116}
          attachable: true
        proxy:
          name: $${NETWORKS_PROXY_NAME:-proxy}
          driver: bridge
          enable_ipv6: true
          ipam:
            driver: default
            config:
              - subnet: $${NETWORKS_PROXY_SUBNET_IPV4:-172.31.128.0/18}
              - subnet: $${NETWORKS_PROXY_SUBNET_IPV6:-fd00:1:be:a:7001:0:3e:7000/116}
          attachable: true
        socket_proxy:
          name: $${NETWORKS_SOCKET_PROXY_NAME:-socket_proxy}
          driver: bridge
          enable_ipv6: true
          ipam:
            driver: default
            config:
              - subnet: $${NETWORKS_SOCKET_PROXY_SUBNET_IPV4:-172.31.192.0/18}
              - subnet: $${NETWORKS_SOCKET_PROXY_SUBNET_IPV6:-fd00:1:be:a:7001:0:3e:8000/116}
          attachable: true
          internal: true

      volumes:
        postgres_data:
        gitlab_config:
        gitlab_logs:
        gitlab_data:
        traefik_acme:
        traefik_logs:
        renovate_logs:
        renovate_db:

runcmd:
  - |
    set -eux
    LOG=/var/log/gitlab-docker-bootstrap.log
    exec >>"$LOG" 2>&1
    echo "=== gitlab-docker bootstrap $(date -Is) ==="
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    . /etc/os-release
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $VERSION_CODENAME stable" > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
%{ if renovate_enabled ~}
    install -m 0755 -d /opt/gitlab/renovate/logs /opt/gitlab/renovate/db
%{ endif ~}
    cd /opt/gitlab
    docker compose pull
    docker compose up -d
    echo "=== finished $(date -Is) ==="
