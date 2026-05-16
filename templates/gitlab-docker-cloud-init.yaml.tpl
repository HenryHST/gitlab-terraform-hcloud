#cloud-config
# GitLab CE + Traefik via Docker Compose under /opt/gitlab (Debian host).
write_files:
  - path: /opt/gitlab/traefik/traefik.yml
    owner: root:root
    permissions: "0644"
    content: |
      entryPoints:
        ping:
          address: ":88"
        web:
          address: ":80"
%{ if acme_enabled ~}
          http:
            redirections:
              entryPoint:
                to: websecure
                scheme: https
%{ endif ~}
        websecure:
          address: ":443"
%{ if acme_enabled ~}
          http:
            tls:
              certResolver: hetzner
%{ endif ~}
        traefik:
          address: ":8080"
      ping:
        entryPoint: "ping"
%{ if acme_enabled ~}
      certificatesResolvers:
        hetzner:
          acme:
            email: "${acme_email}"
            storage: "/certs/acme_letsencrypt.json"
            dnsChallenge:
              provider: "hetzner"
              resolvers:
                - "helium.ns.hetzner.de"
                - "oxygen.ns.hetzner.com"
              delayBeforeCheck: 30s
        tls:
          acme:
            email: "${acme_email}"
            storage: "/certs/tls_letsencrypt.json"
            tlsChallenge: {}
%{ endif ~}
      providers:
        docker:
          endpoint: "unix:///var/run/docker.sock"
          exposedByDefault: false
          network: $${NETWORKS_PROXY_NAME:-proxy}
          watch: true
        file:
          directory: /etc/traefik/dynamic_conf
          watch: true
        providersThrottleDuration: 10s
      global:
        sendAnonymousUsage: false
        checkNewVersion: true
      api:
        dashboard: false
        insecure: false
        debug: false
      experimental:
        plugins:
          fail2ban:
            moduleName: "github.com/tomMoulard/fail2ban"
            version: "v0.8.9"
          sablier:
            moduleName: "github.com/sablierapp/sablier"
            version: "v1.10.1"
      metrics:
        prometheus:
          addRoutersLabels: true
      log:
        level: DEBUG
        filePath: "/var/log/traefik/traefik.log"
        format: json
        maxSize: 10
        maxBackups: 10
        maxAge: 14
      accessLog:
        filePath: "/var/log/traefik/access.log"
        format: common
        bufferingSize: 50
        fields:
          defaultMode: keep
      serversTransport:
        insecureSkipVerify: true

  - path: /opt/gitlab/traefik/.env
    owner: root:root
    permissions: "0600"
    content: |
      ABSOLUTE_PATH=/opt/gitlab
      TZ=Europe/Berlin
      SERVICES_TRAEFIK_LABELS_TRAEFIK_HOST=HOST(`${gitlab_fqdn}`)
      HETZNER_API_TOKEN=${hetzner_api_token}
      ACME_EMAIL=${acme_email}

  - path: /opt/gitlab/traefik/certs/.gitkeep
    owner: root:root
    permissions: "0700"
    content: "#\n"

  - path: /opt/gitlab/traefik/dynamic_conf/http.middlewares.gzip.yml
    owner: root:root
    permissions: "0644"
    content: |
      http:
        middlewares:
          gzip:
            compress: {}

  - path: /opt/gitlab/traefik/dynamic_conf/http.middlewares.fail2ban.yml
    owner: root:root
    permissions: "0644"
    content: |
      http:
        middlewares:
          fail2ban:
            plugin:
              fail2ban:
                allowlist:
                  ip: ::1,127.0.0.1
                denylist:
                  ip: 192.168.10.0/24
                rules:
                  bantime: 3h
                  enabled: "false"
                  findtime: 10m
                  maxretry: "4"
                  statuscode: 400,401,403-499

  - path: /opt/gitlab/traefik/dynamic_conf/http.middlewares.default-security-headers.yml
    owner: root:root
    permissions: "0644"
    content: |
      http:
        middlewares:
          default-security-headers:
            headers:
              browserXssFilter: true
              contentTypeNosniff: true
              forceSTSHeader: true
              frameDeny: true
              stsIncludeSubdomains: true
              stsPreload: true
              stsSeconds: 31536000
              customFrameOptionsValue: "SAMEORIGIN"
              customResponseHeaders:
                Referrer-Policy: "strict-origin-when-cross-origin"
                Content-Security-Policy: "frame-ancestors 'self';"
                Permissions-Policy: "geolocation=(), microphone=(), camera=()"

  - path: /opt/gitlab/traefik/dynamic_conf/http.middlewares.default.yml
    owner: root:root
    permissions: "0644"
    content: |
      http:
        middlewares:
          default:
            chain:
              middlewares:
                - default-security-headers
                - gzip
                - fail2ban

  - path: /opt/gitlab/traefik/dynamic_conf/tls.yml
    owner: root:root
    permissions: "0644"
    content: |
      tls:
        options:
          default:
            minVersion: VersionTLS12
            cipherSuites:
              - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
              - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
              - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
              - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
              - TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305
              - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
              - TLS_AES_128_GCM_SHA256
              - TLS_AES_256_GCM_SHA384
              - TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
            curvePreferences:
              - CurveP521
              - CurveP384
            sniStrict: true
        stores:
          default: {}
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

  # https://docs.gitlab.com/install/docker/configuration/ — /etc/gitlab/gitlab.rb via ./data/config
  - path: /opt/gitlab/data/config/gitlab.rb
    owner: root:root
    permissions: "0600"
    content: |
      ## Managed by Terraform (cloud-init). Edit on host: /opt/gitlab/data/config/gitlab.rb
      ## Then: docker compose exec gitlab gitlab-ctl reconfigure

      external_url '${external_url_scheme}://${gitlab_fqdn}'

      # Traefik terminates TLS; Omnibus HTTP only (https://docs.gitlab.com/omnibus/settings/ssl/#configure-https-with-a-reverse-proxy)
      nginx['listen_port'] = 80
      nginx['listen_https'] = false
%{ if acme_enabled ~}
      letsencrypt['enable'] = false
      nginx['redirect_http_to_https'] = false
      gitlab_rails['trusted_proxies'] = ['127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '172.31.0.0/16']
%{ endif ~}

      # https://docs.gitlab.com/install/docker/configuration/#expose-gitlab-on-different-ports
      gitlab_rails['gitlab_shell_ssh_port'] = 2424

      # External PostgreSQL (docker service postgres on socket_proxy)
      postgresql['enable'] = false
      gitlab_rails['db_adapter'] = 'postgresql'
      gitlab_rails['db_encoding'] = 'unicode'
      gitlab_rails['db_host'] = 'postgres'
      gitlab_rails['db_port'] = 5432
      gitlab_rails['db_username'] = 'gitlab'
      gitlab_rails['db_password'] = '${postgres_password}'
      gitlab_rails['db_database'] = 'gitlabhq_production'
      gitlab_pages['enable'] = false

      # https://docs.gitlab.com/omnibus/settings/smtp.html
%{ if smtp_enabled ~}
      gitlab_rails['smtp_enable'] = true
      gitlab_rails['smtp_address'] = "${smtp_address}"
      gitlab_rails['smtp_port'] = ${smtp_port}
      gitlab_rails['smtp_domain'] = "${smtp_domain}"
      gitlab_rails['smtp_authentication'] = "${smtp_authentication}"
      gitlab_rails['smtp_enable_starttls_auto'] = ${smtp_enable_starttls_auto}
      gitlab_rails['smtp_tls'] = ${smtp_tls}
      gitlab_rails['smtp_openssl_verify_mode'] = '${smtp_openssl_verify_mode}'
%{ if smtp_user_name != "" ~}
      gitlab_rails['smtp_user_name'] = '${smtp_user_name}'
%{ endif ~}
%{ if smtp_password != "" ~}
      gitlab_rails['smtp_password'] = '${smtp_password}'
%{ endif ~}
      gitlab_rails['gitlab_email_from'] = '${gitlab_email_from}'
%{ if gitlab_email_reply_to != "" ~}
      gitlab_rails['gitlab_email_reply_to'] = '${gitlab_email_reply_to}'
%{ endif ~}
%{ else ~}
      gitlab_rails['smtp_enable'] = false
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
            proxy:
              ipv4_address: $${SERVICES_TRAEFIK_NETWORKS_PROXY_IPV4:-172.31.191.247}
              ipv6_address: $${SERVICES_TRAEFIK_NETWORKS_PROXY_IPV6:-fd00:1:be:a:7001:0:3e:7fff}
            socket_proxy:
              ipv4_address: $${SERVICES_TRAEFIK_NETWORKS_SOCKET_PROXY_IPV4:-172.31.255.253}
              ipv6_address: $${SERVICES_TRAEFIK_NETWORKS_SOCKET_PROXY_IPV6:-fd00:1:be:a:7001:0:3e:8ffe}
          ports:
            - "80:80"
            # - "8080:8080"
            - "443:443"
          restart: unless-stopped
          security_opt:
            - no-new-privileges:true
          volumes:
            - /etc/localtime:/etc/localtime:ro
            - /var/run/docker.sock:/var/run/docker.sock:ro
            - ./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
            - ./traefik/dynamic_conf:/etc/traefik/dynamic_conf:ro
            - ./traefik/certs:/certs
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
            - ./postgres/data:/var/lib/postgresql/data
          networks:
            socket_proxy:
              ipv4_address: $${SERVICES_POSTGRES_NETWORKS_SOCKET_PROXY_IPV4:-172.31.255.252}
              ipv6_address: $${SERVICES_POSTGRES_NETWORKS_SOCKET_PROXY_IPV6:-fd00:1:be:a:7001:0:3e:8ffd}
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
          volumes:
            - ./data/config:/etc/gitlab
            - ./data/logs:/var/log/gitlab
            - ./data/gitlab:/var/opt/gitlab
          ports:
            - "2424:22"
          networks:
            proxy:
              ipv4_address: $${SERVICES_GITLAB_NETWORKS_PROXY_IPV4:-172.31.129.254}
              ipv6_address: $${SERVICES_GITLAB_NETWORKS_PROXY_IPV6:-fd00:1:be:a:7001:0:3e:7ffe}
            socket_proxy:
          labels:
            - "traefik.enable=true"
            - "traefik.docker.network=$${NETWORKS_PROXY_NAME:-proxy}"
            - "traefik.http.services.gitlab.loadbalancer.server.port=80"
%{ if acme_enabled ~}
            - "traefik.http.routers.gitlab.rule=Host(`${gitlab_fqdn}`)"
            - "traefik.http.routers.gitlab.entrypoints=websecure"
            - "traefik.http.routers.gitlab.tls=true"
            - "traefik.http.routers.gitlab.tls.certresolver=hetzner"
            - "traefik.http.routers.gitlab.tls.options=default@file"
%{ else ~}
            - "traefik.http.routers.gitlab.rule=Host(`${gitlab_fqdn}`)"
            - "traefik.http.routers.gitlab.entrypoints=web"
%{ endif ~}
            - "traefik.http.routers.gitlab.middlewares=default@file"
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
            proxy:
              ipv4_address: $${SERVICES_RENOVATE_NETWORKS_PROXY_IPV4:-172.31.129.251}
              ipv6_address: $${SERVICES_RENOVATE_NETWORKS_PROXY_IPV6:-fd00:1:be:a:7001:0:3e:7ffd}
          labels:
            - "traefik.enable=true"
            - "traefik.docker.network=$${NETWORKS_PROXY_NAME:-proxy}"
            - "traefik.http.services.renovate.loadbalancer.server.port=8080"
%{ if acme_enabled ~}
            - "traefik.http.routers.renovate.rule=Host(`${renovate_fqdn}`)"
            - "traefik.http.routers.renovate.entrypoints=websecure"
            - "traefik.http.routers.renovate.tls=true"
            - "traefik.http.routers.renovate.tls.certresolver=hetzner"
            - "traefik.http.routers.renovate.tls.options=default@file"
%{ else ~}
            - "traefik.http.routers.renovate.rule=Host(`${renovate_fqdn}`)"
            - "traefik.http.routers.renovate.entrypoints=web"
%{ endif ~}
            - "traefik.http.routers.renovate.middlewares=default@file"
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
    install -m 0700 -d /opt/gitlab/traefik/certs
    install -m 0700 -d /opt/gitlab/postgres/data
    chown 999:999 /opt/gitlab/postgres/data
    install -m 0755 -d /opt/gitlab/data/config /opt/gitlab/data/logs /opt/gitlab/data/gitlab
%{ if renovate_enabled ~}
    install -m 0755 -d /opt/gitlab/renovate/logs /opt/gitlab/renovate/db
%{ endif ~}
    cd /opt/gitlab
    docker compose pull
    docker compose up -d
    echo "=== finished $(date -Is) ==="
