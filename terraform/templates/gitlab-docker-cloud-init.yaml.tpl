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
          # Keep gitlab@docker router while GitLab Omnibus healthcheck is still starting (avoids Traefik 404).
          allowEmptyServices: true
          # Static config: literal Docker network name (not shell/env substitution).
          network: proxy
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
%{ if traefik_hardening_enabled ~}
        level: ${traefik_log_level}
%{ else ~}
        level: DEBUG
%{ endif ~}
        filePath: "/var/log/traefik/traefik.log"
        format: json
        maxSize: 10
        maxBackups: 10
        maxAge: 14
      accessLog:
        filePath: "/var/log/traefik/access.log"
%{ if traefik_hardening_enabled ~}
        format: ${traefik_access_log_format}
%{ else ~}
        format: common
%{ endif ~}
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
                  bantime: ${traefik_fail2ban_bantime}
%{ if traefik_fail2ban_enabled ~}
                  enabled: "true"
%{ else ~}
                  enabled: "false"
%{ endif ~}
                  findtime: ${traefik_fail2ban_findtime}
                  maxretry: "${traefik_fail2ban_maxretry}"
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

%{ if traefik_rate_limit_enabled ~}
  - path: /opt/gitlab/traefik/dynamic_conf/http.middlewares.rate-limit.yml
    owner: root:root
    permissions: "0644"
    content: |
      http:
        middlewares:
          rate-limit:
            rateLimit:
              average: ${traefik_rate_limit_average}
              burst: ${traefik_rate_limit_burst}
              period: 1s

%{ endif ~}
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
%{ if traefik_rate_limit_enabled ~}
                - rate-limit
%{ endif ~}
                - fail2ban

  - path: /opt/gitlab/traefik/dynamic_conf/tls.yml
    owner: root:root
    permissions: "0644"
    content: |
      tls:
        options:
          # Name must not be "default" when referenced as name@file from Docker labels (Traefik v3).
          secure:
%{ if traefik_hardening_enabled ~}
            minVersion: ${traefik_tls_min_version}
%{ else ~}
            minVersion: VersionTLS12
%{ endif ~}
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
%{ if runner_enabled && runner_static_config ~}
  - path: /opt/gitlab/gitlab-runner/config.toml
    owner: root:root
    permissions: "0600"
    content: |
      concurrent = ${runner_concurrent}
      check_interval = 0
      shutdown_timeout = 0

      [session_server]
        session_timeout = 1800

      [[runners]]
        name = "${runner_description}"
        url = "${gitlab_url}/"
        token = "${runner_token}"
        executor = "${runner_executor}"
        tag_list = [${runner_tag_list}]
%{ if runner_executor == "docker" ~}
        [runners.docker]
          tls_verify = false
          image = "${runner_default_image}"
          privileged = ${runner_privileged}
          disable_entrypoint_overwrite = false
          oom_kill_disable = false
          disable_cache = false
          volumes = ["/cache"]
          shm_size = 0
          network_mode = "bridge"
%{ endif ~}
%{ endif ~}
%{ if runner_autoregister ~}

  - path: /opt/gitlab/scripts/gitlab-runner-autoregister.sh
    owner: root:root
    permissions: "0750"
    content: |
      #!/usr/bin/env bash
      # Create instance runner(s) via POST /api/v4/user/runners (https://docs.gitlab.com/tutorials/automate_runner_creation/)
      set -euo pipefail
      COMPOSE_DIR=/opt/gitlab
      LOG=/var/log/gitlab-runner-autoregister.log
      exec >>"$LOG" 2>&1
      echo "=== gitlab-runner-autoregister $(date -Is) ==="
      cd "$COMPOSE_DIR"

      create_bootstrap_pat() {
        docker compose exec -T gitlab gitlab-rails runner "
          u = User.find_by_username('root')
          raise 'root user missing' unless u
          pat = u.personal_access_tokens.create!(
            name: 'runner-bootstrap-terraform',
            scopes: [:api],
            expires_at: 1.day.from_now
          )
          puts pat.token
        " 2>/dev/null | tail -1 | tr -d '\r'
      }

      revoke_bootstrap_pat() {
        docker compose exec -T gitlab gitlab-rails runner "
          u = User.find_by_username('root')
          u.personal_access_tokens.find_by(name: 'runner-bootstrap-terraform')&.revoke!
        " 2>/dev/null || true
      }

      register_runner() {
        local pat="$1" description="$2" tag_list="$3"
        docker compose exec -T gitlab curl -sf \
          --request POST "http://localhost/api/v4/user/runners" \
          --header "PRIVATE-TOKEN: $pat" \
          --form "runner_type=instance_type" \
          --form "description=$description" \
          --form "tag_list=$tag_list" \
          2>/dev/null || true
      }

%{ if runner_buildah_enabled ~}
      write_config_buildah() {
        {
          echo "concurrent = ${runner_concurrent}"
          echo "check_interval = 0"
          echo "shutdown_timeout = 0"
          echo ""
%{ for idx, p in runner_buildah_profiles ~}
          echo "[[runners]]"
          echo "  name = \"${p.name}\""
          echo "  url = \"${gitlab_url}\""
          echo "  token = \"$${GLRT_TOKENS[${idx}]}\""
          echo "  executor = \"docker\""
          echo "  run_untagged = ${p.run_untagged}"
          echo "  [runners.docker]"
          echo "    tls_verify = false"
          echo "    privileged = ${p.privileged}"
%{ if p.security_opt ~}
          echo "    security_opt = [\"seccomp=unconfined\", \"apparmor=unconfined\"]"
%{ endif ~}
          echo "    volumes = [\"/cache\"]"
          echo ""
%{ endfor ~}
        } >"$COMPOSE_DIR/gitlab-runner/config.toml"
        chmod 0600 "$COMPOSE_DIR/gitlab-runner/config.toml"
      }

      for attempt in $(seq 1 40); do
        if [ "$(docker compose ps gitlab --format '{{.State}}' 2>/dev/null | head -1)" != "running" ]; then
          echo "attempt $attempt: gitlab not running yet"
          sleep 30
          continue
        fi
        PAT="$(create_bootstrap_pat)"
        if [ -z "$PAT" ]; then
          echo "attempt $attempt: could not create bootstrap PAT"
          sleep 30
          continue
        fi
        GLRT_TOKENS=()
        buildah_ok=true
%{ for p in runner_buildah_profiles ~}
        RESP="$(register_runner "$PAT" "${p.name}" "${p.tags_api}")"
        GLRT="$(printf '%s' "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('token',''))" 2>/dev/null || true)"
        if [ -z "$GLRT" ]; then
          echo "attempt $attempt: user/runners API failed for ${p.name}: $RESP"
          buildah_ok=false
        else
          GLRT_TOKENS+=("$GLRT")
        fi
%{ endfor ~}
        revoke_bootstrap_pat
        if [ "$buildah_ok" = true ] && [ "$${#GLRT_TOKENS[@]}" -eq ${length(runner_buildah_profiles)} ]; then
          write_config_buildah
          docker compose --profile runner up -d gitlab-runner
          echo "=== runner autoregister ok (buildah x${length(runner_buildah_profiles)}) $(date -Is) ==="
          exit 0
        fi
        sleep 30
      done
%{ else ~}
      write_config() {
        local glrt_token="$1"
        {
          echo "concurrent = ${runner_concurrent}"
          echo "check_interval = 0"
          echo "shutdown_timeout = 0"
          echo ""
          echo "[session_server]"
          echo "  session_timeout = 1800"
          echo ""
          echo "[[runners]]"
          echo "  name = \"${runner_description}\""
          echo "  url = \"${gitlab_url}/\""
          echo "  token = \"$glrt_token\""
          echo "  executor = \"${runner_executor}\""
          printf '%s\n' '  tag_list = [${runner_tag_list}]'
%{ if runner_executor == "docker" ~}
          echo ""
          echo "  [runners.docker]"
          echo "    tls_verify = false"
          echo "    image = \"${runner_default_image}\""
          echo "    privileged = ${runner_privileged}"
          echo "    disable_entrypoint_overwrite = false"
          echo "    oom_kill_disable = false"
          echo "    disable_cache = false"
          echo "    volumes = [\"/cache\"]"
          echo "    shm_size = 0"
          echo "    network_mode = \"bridge\""
%{ endif ~}
        } >"$COMPOSE_DIR/gitlab-runner/config.toml"
        chmod 0600 "$COMPOSE_DIR/gitlab-runner/config.toml"
      }

      for attempt in $(seq 1 40); do
        if [ "$(docker compose ps gitlab --format '{{.State}}' 2>/dev/null | head -1)" != "running" ]; then
          echo "attempt $attempt: gitlab not running yet"
          sleep 30
          continue
        fi
        PAT="$(create_bootstrap_pat)"
        if [ -z "$PAT" ]; then
          echo "attempt $attempt: could not create bootstrap PAT"
          sleep 30
          continue
        fi
        RESP="$(register_runner "$PAT" "${runner_description}" "${runner_tag_list_api}")"
        revoke_bootstrap_pat
        GLRT="$(printf '%s' "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('token',''))" 2>/dev/null || true)"
        if [ -n "$GLRT" ]; then
          write_config "$GLRT"
          docker compose --profile runner up -d gitlab-runner
          echo "=== runner autoregister ok $(date -Is) ==="
          exit 0
        fi
        echo "attempt $attempt: user/runners API failed: $RESP"
        sleep 30
      done
%{ endif ~}
      echo "=== runner autoregister timed out $(date -Is) ===" >&2
      exit 1
%{ endif ~}
%{ if host_hardening_enabled ~}

  - path: /etc/ssh/sshd_config.d/99-gitlab-terraform.conf
    owner: root:root
    permissions: "0644"
    content: |
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitEmptyPasswords no
      PermitRootLogin prohibit-password
      AllowUsers ${join(" ", host_hardening_ssh_allow_users)}

  - path: /etc/sysctl.d/99-gitlab-docker-host.conf
    owner: root:root
    permissions: "0644"
    content: |
      net.ipv4.ip_forward = 1
      net.ipv4.conf.all.rp_filter = 1
      net.ipv4.conf.default.rp_filter = 1
      net.ipv4.tcp_syncookies = 1
      net.ipv4.conf.all.accept_redirects = 0
      net.ipv6.conf.all.accept_redirects = 0
      net.ipv4.conf.all.send_redirects = 0
      net.ipv4.conf.all.accept_source_route = 0
      net.ipv6.conf.all.accept_source_route = 0
      kernel.kptr_restrict = 1
      kernel.dmesg_restrict = 1

  - path: /etc/fail2ban/jail.local
    owner: root:root
    permissions: "0644"
    content: |
      [DEFAULT]
      bantime  = 1h
      findtime = 10m
      maxretry = 5
      banaction = ufw

      [sshd]
      enabled = true
      port    = ssh
      backend = systemd

      [recidive]
      enabled  = true
      logpath  = /var/log/fail2ban.log
      banaction = ufw
      bantime  = 1w
      findtime = 1d
      maxretry = 5
%{ if host_hardening_unattended_upgrades ~}

  - path: /etc/apt/apt.conf.d/20auto-upgrades
    owner: root:root
    permissions: "0644"
    content: |
      APT::Periodic::Update-Package-Lists "1";
      APT::Periodic::Unattended-Upgrade "1";
      APT::Periodic::AutocleanInterval "7";

  - path: /etc/apt/apt.conf.d/50unattended-upgrades
    owner: root:root
    permissions: "0644"
    content: |
      Unattended-Upgrade::Allowed-Origins {
          "$${distro_id}:$${distro_codename}-security";
          "$${distro_id}ESMApps:$${distro_codename}-apps-security";
          "$${distro_id}ESM:$${distro_codename}-infra-security";
      };
      Unattended-Upgrade::Remove-Unused-Dependencies "true";
      Unattended-Upgrade::Automatic-Reboot "false";
%{ endif ~}
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
%{ if gitlab_display_initial_root_password ~}
      gitlab_rails['display_initial_root_password'] = true
      gitlab_rails['store_initial_root_password'] = true
%{ else ~}
      gitlab_rails['display_initial_root_password'] = false
%{ endif ~}

      # External PostgreSQL (docker service postgres on socket_proxy)
      postgresql['enable'] = false
      gitlab_rails['db_adapter'] = 'postgresql'
      gitlab_rails['db_encoding'] = 'unicode'
      gitlab_rails['db_host'] = 'postgres'
      gitlab_rails['db_port'] = 5432
      gitlab_rails['db_username'] = 'gitlab'
      gitlab_rails['db_password'] = '${postgres_password}'
      gitlab_rails['db_database'] = 'gitlabhq_production'
%{ if pages_enabled ~}

      # GitLab Pages behind Traefik (https://docs.gitlab.com/administration/pages/)
      pages_external_url '${external_url_scheme}://${pages_fqdn}'
      gitlab_pages['enable'] = true
      gitlab_pages['listen_proxy'] = '0.0.0.0:8090'
      gitlab_pages['custom_domain_mode'] = 'http'
      pages_nginx['enable'] = false
%{ if acme_enabled ~}
      pages_nginx['real_ip_header'] = 'X-Forwarded-For'
      pages_nginx['real_ip_trusted_cidr'] = ['127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '172.31.0.0/16']
%{ endif ~}
%{ else ~}
      gitlab_pages['enable'] = false
%{ endif ~}
      gitlab_rails['gitlab_default_theme'] = ${gitlab_theme_id}
      gitlab_rails['gitlab_default_color_mode'] = ${gitlab_color_mode}
      gitlab_rails['time_zone'] = '${gitlab_time_zone}'
      gitlab_rails['gitlab_default_can_create_group'] = true
      gitlab_rails['gitlab_username_changing_enabled'] = true
      gitlab_rails['webhook_timeout'] = 10
%{ if artifacts_enabled ~}

      # https://docs.gitlab.com/administration/cicd/job_artifacts/
      gitlab_rails['artifacts_enabled'] = true
      gitlab_rails['artifacts_path'] = "${artifacts_path}"
%{ else ~}
      gitlab_rails['artifacts_enabled'] = false
%{ endif ~}
      gitlab_rails['gitlab_signup_enabled'] = ${gitlab_signup_enabled}
%{ if registry_enabled ~}

      # Container Registry behind Traefik (https://docs.gitlab.com/administration/packages/container_registry/)
      registry_external_url '${external_url_scheme}://${registry_fqdn}'
      gitlab_rails['registry_enabled'] = true
      registry['enable'] = true
      registry_nginx['enable'] = false
      registry['registry_http_addr'] = "0.0.0.0:5050"
%{ if acme_enabled ~}
      registry['trusted_proxies'] = ['127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '172.31.0.0/16']
%{ endif ~}
%{ endif ~}

      # https://docs.gitlab.com/omnibus/settings/backups.html
%{ if backup_enabled ~}
      gitlab_rails['manage_backup_path'] = true
      gitlab_rails['backup_path'] = "/var/opt/gitlab/backups"
      gitlab_rails['backup_keep_time'] = ${backup_keep_time}
%{ endif ~}

      # https://docs.gitlab.com/ee/administration/terraform_state
%{ if terraform_enabled ~}
      gitlab_rails['terraform_enabled'] = true
      gitlab_rails['terraform_state_storage'] = 'local'
      gitlab_rails['terraform_state_path'] = "${gitlab_terraform_state_path}"
      gitlab_rails['terraform_state_file'] = "${gitlab_terraform_state_file}"
%{ endif ~}

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
%{ if plantuml_enabled ~}

      # https://docs.gitlab.com/administration/integration/plantuml/ — proxy /-/plantuml/ to Compose service plantuml:8080
      nginx['custom_gitlab_server_config'] = "location /-/plantuml/ { \n  rewrite ^/-/plantuml/(.*) /$1 break;\n  proxy_cache off;\n  proxy_pass http://plantuml:8080/;\n}\n"
      gitlab_rails['env'] = { 'PLANTUML_ENCODING' => 'deflate' }
%{ endif ~}
%{ if backup_enabled ~}

  # Backup/restore scripts (manual, cron, or GitLab CI). See /opt/gitlab/docs/BACKUP.md
  - path: /opt/gitlab/scripts/gitlab-backup.sh
    owner: root:root
    permissions: "0750"
    content: |
      #!/usr/bin/env bash
      # Application + gitlab.rb/config backup. Archives: /opt/gitlab/backups (bind-mount).
      set -euo pipefail
      COMPOSE_DIR=/opt/gitlab
      LOG=/var/log/gitlab-backup.log
      LOCK=/var/run/gitlab-backup.lock
      SOURCE="$${GITLAB_BACKUP_SOURCE:-manual}"
      exec 9>"$LOCK"
      flock -n 9 || { echo "gitlab-backup already running (lock $LOCK)"; exit 1; }
      exec >>"$LOG" 2>&1
      echo "=== gitlab-backup $(date -Is) source=$SOURCE ==="
      cd "$COMPOSE_DIR"
      if [ "$(docker compose ps gitlab --format '{{.State}}' 2>/dev/null | head -1)" != "running" ]; then
        echo "ERROR: gitlab service not running"
        exit 1
      fi
      BACKUP_ARGS=(gitlab-backup create)
      if [[ "$SOURCE" == "cron" || "$${CRON:-}" == "1" ]]; then
        BACKUP_ARGS+=(CRON=1)
      fi
      docker compose exec -T gitlab "$${BACKUP_ARGS[@]}"
      docker compose exec -T gitlab gitlab-ctl backup-etc --delete-old-backups
      echo "=== finished $(date -Is) source=$SOURCE ==="

  - path: /opt/gitlab/scripts/gitlab-restore.sh
    owner: root:root
    permissions: "0750"
    content: |
      #!/usr/bin/env bash
      # Restore GitLab application and/or config from backups (see gitlab-backup.sh).
      # https://docs.gitlab.com/administration/backup_restore/restore_gitlab/
      set -euo pipefail
      COMPOSE_DIR=/opt/gitlab
      BACKUP_DIR=/opt/gitlab/backups
      CONFIG_BACKUP_DIR=/opt/gitlab/data/config/config_backup
      LOG=/var/log/gitlab-restore.log

      usage() {
        cat <<'EOF'
      Usage:
        gitlab-restore.sh --list
        gitlab-restore.sh --config-only [gitlab_config_TIMESTAMP.tar]
        gitlab-restore.sh <BACKUP_ID>

      BACKUP_ID is the archive name without _gitlab_backup.tar (e.g. 1234567890_2026_05_16_18.10.5-ce.0).
      Set GITLAB_RESTORE_FORCE=1 to skip confirmation. Destructive: overwrites GitLab data.
      EOF
      }

      log() { echo "=== gitlab-restore $(date -Is) $* ===" >>"$LOG"; }
      die() { echo "ERROR: $*" >&2; exit 1; }

      confirm() {
        [[ "$${GITLAB_RESTORE_FORCE:-}" == "1" ]] && return 0
        echo "WARNING: This overwrites GitLab data. Continue? [y/N]" >&2
        read -r ans
        [[ "$ans" == [yY] || "$ans" == [yY][eE][sS] ]] || exit 1
      }

      list_backups() {
        local f id
        shopt -s nullglob
        for f in "$BACKUP_DIR"/*_gitlab_backup.tar; do
          id=$(basename "$f" _gitlab_backup.tar)
          echo "$id"
        done
        shopt -u nullglob
      }

      restore_config() {
        local tarfile="$${1:-}"
        if [[ -z "$tarfile" ]]; then
          tarfile=$(ls -t "$CONFIG_BACKUP_DIR"/gitlab_config_*.tar 2>/dev/null | head -1 || true)
        fi
        [[ -n "$tarfile" && -f "$tarfile" ]] || die "no config backup in $CONFIG_BACKUP_DIR"
        local inner="/etc/gitlab/config_backup/$(basename "$tarfile")"
        cd "$COMPOSE_DIR"
        log "config-only $inner"
        exec >>"$LOG" 2>&1
        docker compose exec -T gitlab gitlab-ctl stop
        docker compose exec -T gitlab bash -c "cd / && tar -xf '$inner'"
        docker compose exec -T gitlab gitlab-ctl reconfigure
        docker compose restart gitlab
        echo "=== config restore finished $(date -Is) ==="
      }

      restore_app() {
        local id="$1"
        local archive="$BACKUP_DIR/$${id}_gitlab_backup.tar"
        [[ -f "$archive" ]] || die "backup not found: $archive"
        cd "$COMPOSE_DIR"
        if [ "$(docker compose ps gitlab --format '{{.State}}' 2>/dev/null | head -1)" != "running" ]; then
          die "gitlab service not running"
        fi
        log "application BACKUP=$id"
        exec >>"$LOG" 2>&1
        docker compose exec -T gitlab gitlab-ctl stop puma
        docker compose exec -T gitlab gitlab-ctl stop sidekiq
        docker compose exec -T gitlab gitlab-backup restore BACKUP="$id"
        docker compose restart gitlab
        docker compose exec -T gitlab gitlab-rake gitlab:check SANITIZE=true || true
        echo "=== application restore finished $(date -Is) ==="
      }

      main() {
        case "$${1:-}" in
          -h|--help) usage; exit 0 ;;
          --list|-l) list_backups; exit 0 ;;
          --config-only)
            confirm
            restore_config "$${2:-}"
            ;;
          "")
            usage
            echo >&2
            echo "Available application backups:" >&2
            list_backups || echo "(none)" >&2
            exit 1
            ;;
          *)
            confirm
            restore_app "$1"
            ;;
        esac
      }

      main "$@"

  - path: /opt/gitlab/docs/BACKUP.md
    owner: root:root
    permissions: "0644"
    content: |
      # GitLab backups on this host

      - **Automatic:** cron when `gitlab_docker_backup_auto_enabled` (Terraform); schedule via `gitlab_docker_backup_time` or `gitlab_docker_backup_cron`.
      - **Manual:** `sudo /opt/gitlab/scripts/gitlab-backup.sh` (set `GITLAB_BACKUP_SOURCE=manual`).
      - **GitLab CI:** use a shell runner on this host; see repo `docs/examples/gitlab-backup-ci.yml.example` and `docs/backup.md`.
      - **Restore:** `/opt/gitlab/scripts/gitlab-restore.sh --list`
      - Log: `/var/log/gitlab-backup.log` — Archives: `/opt/gitlab/backups/`

      There is no GitLab REST API for full-instance backups on self-managed CE.
%{ if backup_auto_enabled ~}

  - path: /etc/cron.d/gitlab-backup
    owner: root:root
    permissions: "0644"
    content: |
      SHELL=/bin/bash
      PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
      ${backup_cron_effective} root GITLAB_BACKUP_SOURCE=cron /opt/gitlab/scripts/gitlab-backup.sh
%{ endif ~}
%{ endif ~}
%{ if plantuml_enabled ~}

  - path: /opt/gitlab/scripts/gitlab-plantuml-enable.sh
    owner: root:root
    permissions: "0750"
    content: |
      #!/usr/bin/env bash
      # Enable PlantUML in ApplicationSettings after GitLab is up (Admin UI equivalent).
      set -euo pipefail
      COMPOSE_DIR=/opt/gitlab
      PLANTUML_URL='${plantuml_url}'
      LOG=/var/log/gitlab-plantuml-enable.log
      exec >>"$LOG" 2>&1
      echo "=== gitlab-plantuml-enable $(date -Is) url=$PLANTUML_URL ==="
      cd "$COMPOSE_DIR"
      for attempt in $(seq 1 40); do
        if [ "$(docker compose ps gitlab --format '{{.State}}' 2>/dev/null | head -1)" != "running" ]; then
          echo "attempt $attempt: gitlab not running yet"
          sleep 30
          continue
        fi
        if docker compose exec -T gitlab gitlab-rails runner \
          "ApplicationSetting.current.update!(plantuml_enabled: true, plantuml_url: '${plantuml_url}'); puts 'plantuml_ok'" \
          2>/dev/null | grep -q plantuml_ok; then
          echo "=== plantuml enabled $(date -Is) ==="
          exit 0
        fi
        echo "attempt $attempt: rails runner not ready"
        sleep 30
      done
      echo "=== plantuml enable timed out $(date -Is) ===" >&2
      exit 1
%{ endif ~}

%{ if compose_hardening_enabled ~}
  - path: /etc/docker/daemon.json
    owner: root:root
    permissions: "0644"
    content: |
      {
%{ if compose_daemon_icc_disabled ~}
        "icc": false,
%{ else ~}
        "icc": true,
%{ endif ~}
%{ if compose_daemon_live_restore ~}
        "live-restore": true,
%{ endif ~}
%{ if compose_daemon_userland_proxy ~}
        "userland-proxy": true,
%{ else ~}
        "userland-proxy": false,
%{ endif ~}
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "${compose_log_max_size}",
          "max-file": "${compose_log_max_file}"
        }
      }

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
%{ if compose_container_log_rotation ~}
          logging:
            driver: json-file
            options:
              max-size: "${compose_log_max_size}"
              max-file: "${compose_log_max_file}"
%{ endif ~}
          volumes:
            - /etc/localtime:/etc/localtime:ro
            - /var/run/docker.sock:/var/run/docker.sock:ro
            - ./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
            - ./traefik/dynamic_conf:/etc/traefik/dynamic_conf:ro
            - ./traefik/certs:/certs
            - /var/log/traefik/:/var/log/traefik
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
%{ if compose_container_no_new_privileges ~}
          security_opt:
            - no-new-privileges:true
%{ endif ~}
%{ if compose_container_log_rotation ~}
          logging:
            driver: json-file
            options:
              max-size: "${compose_log_max_size}"
              max-file: "${compose_log_max_file}"
%{ endif ~}

        gitlab:
          image: ${gitlab_ce_image}
          restart: unless-stopped
          hostname: "${gitlab_fqdn}"
          shm_size: "256m"
          # Image HEALTHCHECK keeps container "starting" for several minutes; Traefik then drops the router (404).
          healthcheck:
            disable: true
%{ if compose_container_no_new_privileges ~}
          security_opt:
            - no-new-privileges:true
%{ endif ~}
%{ if compose_container_log_rotation ~}
          logging:
            driver: json-file
            options:
              max-size: "${compose_log_max_size}"
              max-file: "${compose_log_max_file}"
%{ endif ~}
          depends_on:
            postgres:
              condition: service_healthy
%{ if plantuml_enabled ~}
            plantuml:
              condition: service_started
%{ endif ~}
          environment:
            GITLAB_ROOT_EMAIL: "${gitlab_root_email}"
            GITLAB_ROOT_PASSWORD: "${gitlab_root_password}"
          volumes:
            - ./data/config:/etc/gitlab
            - ./data/logs:/var/log/gitlab
            - ./data/gitlab:/var/opt/gitlab
%{ if backup_enabled ~}
            - ./backups:/var/opt/gitlab/backups
%{ endif ~}
%{ if artifacts_enabled ~}
            - ./artifacts/data:${artifacts_path}
%{ endif ~}
%{ if registry_enabled ~}
            - ./registry/data:/var/opt/gitlab/gitlab-rails/shared/registry
            - ./registry/certs:/etc/gitlab/ssl/registry
%{ endif ~}
%{ if terraform_enabled ~}
            - ./data/terraform/state:${gitlab_terraform_state_path}
%{ endif ~}
          ports:
            - "2424:22"
          networks:
            proxy:
              ipv4_address: $${SERVICES_GITLAB_NETWORKS_PROXY_IPV4:-172.31.129.254}
              ipv6_address: $${SERVICES_GITLAB_NETWORKS_PROXY_IPV6:-fd00:1:be:a:7001:0:3e:7ffe}
            socket_proxy: {}
          labels:
            - "traefik.enable=true"
            - "traefik.docker.network=$${NETWORKS_PROXY_NAME:-proxy}"
            - "traefik.http.services.gitlab.loadbalancer.server.port=80"
            - "traefik.http.routers.gitlab.service=gitlab"
%{ if acme_enabled ~}
            - "traefik.http.routers.gitlab.rule=Host(`${gitlab_fqdn}`)"
            - "traefik.http.routers.gitlab.entrypoints=websecure"
            - "traefik.http.routers.gitlab.tls=true"
            - "traefik.http.routers.gitlab.tls.certresolver=hetzner"
%{ else ~}
            - "traefik.http.routers.gitlab.rule=Host(`${gitlab_fqdn}`)"
            - "traefik.http.routers.gitlab.entrypoints=web"
%{ endif ~}
            - "traefik.http.routers.gitlab.middlewares=default@file"
%{ if registry_enabled ~}
            - "traefik.http.middlewares.registry-buffering.buffering.maxRequestBodyBytes=0"
            - "traefik.http.services.registry.loadbalancer.server.port=5050"
            - "traefik.http.routers.registry.service=registry"
%{ if acme_enabled ~}
            - "traefik.http.routers.registry.rule=Host(`${registry_fqdn}`)"
            - "traefik.http.routers.registry.entrypoints=websecure"
            - "traefik.http.routers.registry.tls=true"
            - "traefik.http.routers.registry.tls.certresolver=hetzner"
%{ else ~}
            - "traefik.http.routers.registry.rule=Host(`${registry_fqdn}`)"
            - "traefik.http.routers.registry.entrypoints=web"
%{ endif ~}
            - "traefik.http.routers.registry.middlewares=registry-buffering@docker,default@file"
%{ endif ~}
%{ if pages_enabled ~}
            - "traefik.http.services.pages.loadbalancer.server.port=8090"
            - "traefik.http.routers.pages.service=pages"
            - 'traefik.http.routers.pages.rule=Host(`${pages_fqdn}`) || HostRegexp(`^.+\\.${pages_fqdn_host_regex}$$`)'
            - "traefik.http.routers.pages.entrypoints=websecure"
            - "traefik.http.routers.pages.tls=true"
            - "traefik.http.routers.pages.tls.certresolver=hetzner"
            - "traefik.http.routers.pages.tls.domains[0].main=${pages_fqdn}"
            - "traefik.http.routers.pages.tls.domains[0].sans=*.${pages_fqdn}"
            - "traefik.http.routers.pages.middlewares=default@file"
%{ endif ~}
%{ if plantuml_enabled ~}

        plantuml:
          container_name: plantuml
          image: ${plantuml_image}
          restart: unless-stopped
%{ if compose_container_no_new_privileges ~}
          security_opt:
            - no-new-privileges:true
%{ endif ~}
%{ if compose_container_log_rotation ~}
          logging:
            driver: json-file
            options:
              max-size: "${compose_log_max_size}"
              max-file: "${compose_log_max_file}"
%{ endif ~}
          networks:
            socket_proxy: {}
%{ endif ~}
%{ if runner_enabled ~}

        gitlab-runner:
          container_name: $${SERVICES_GITLAB_RUNNER_CONTAINER_NAME:-gitlab-runner}
          image: ${runner_image}
          restart: unless-stopped
%{ if runner_autoregister ~}
          profiles:
            - runner
%{ endif ~}
          depends_on:
            gitlab:
              condition: service_started
          extra_hosts:
            - "${gitlab_fqdn}:${traefik_proxy_ipv4}"
          volumes:
            - ./gitlab-runner:/etc/gitlab-runner
            - /var/run/docker.sock:/var/run/docker.sock
%{ if compose_container_no_new_privileges ~}
          security_opt:
            - no-new-privileges:true
%{ endif ~}
%{ if compose_container_log_rotation ~}
          logging:
            driver: json-file
            options:
              max-size: "${compose_log_max_size}"
              max-file: "${compose_log_max_file}"
%{ endif ~}
          networks:
            proxy:
              ipv4_address: $${SERVICES_GITLAB_RUNNER_NETWORKS_PROXY_IPV4:-172.31.129.250}
              ipv6_address: $${SERVICES_GITLAB_RUNNER_NETWORKS_PROXY_IPV6:-fd00:1:be:a:7001:0:3e:7ffc}
            socket_proxy: {}
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
          ports:
            - "8084:8080"
          volumes:
            - renovate_logs:/logs
            - renovate_db:/db
            - /etc/localtime:/etc/localtime:ro
%{ if compose_container_no_new_privileges ~}
          security_opt:
            - no-new-privileges:true
%{ endif ~}
%{ if compose_container_log_rotation ~}
          logging:
            driver: json-file
            options:
              max-size: "${compose_log_max_size}"
              max-file: "${compose_log_max_file}"
%{ endif ~}
          networks:
            proxy:
              ipv4_address: $${SERVICES_RENOVATE_NETWORKS_PROXY_IPV4:-172.31.129.251}
              ipv6_address: $${SERVICES_RENOVATE_NETWORKS_PROXY_IPV6:-fd00:1:be:a:7001:0:3e:7ffd}
          labels:
            - "traefik.enable=true"
            - "traefik.docker.network=$${NETWORKS_PROXY_NAME:-proxy}"
            - "traefik.http.services.renovate.loadbalancer.server.port=8084"
%{ if acme_enabled ~}
            - "traefik.http.routers.renovate.rule=Host(`${renovate_fqdn}`)"
            - "traefik.http.routers.renovate.entrypoints=websecure"
            - "traefik.http.routers.renovate.tls=true"
            - "traefik.http.routers.renovate.tls.certresolver=hetzner"
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
        #traefik_logs:
        renovate_logs:
        renovate_db:

  - path: /etc/zsh/zshrc.d/99-gitlab-docker-host.zsh
    owner: root:root
    permissions: "0644"
    content: |
      # GitLab Docker host — system-wide zsh (all users)
      HISTFILE=~/.zsh_history
      HISTSIZE=10000
      SAVEHIST=10000
      setopt SHARE_HISTORY INC_APPEND_HISTORY HIST_IGNORE_DUPS

      autoload -Uz compinit
      compinit -C

      [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
        source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

      # Syntax highlighting must be sourced last
      [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
        source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

      if command -v docker >/dev/null 2>&1; then
        source <(docker completion zsh) 2>/dev/null
        source <(docker compose completion zsh) 2>/dev/null
      fi

%{ if gitlab_admin_enabled ~}
users:
  - name: ${gitlab_admin_username}
    gecos: GitLab Docker Host Administrator
    shell: /bin/zsh
    groups: [sudo]
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - ${gitlab_admin_ssh_public_key}
%{ endif ~}

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
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin zsh zsh-autosuggestions zsh-syntax-highlighting ${host_hardening_apt_packages}
    if grep -q '^SHELL=' /etc/default/useradd; then
      sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' /etc/default/useradd
    else
      echo 'SHELL=/usr/bin/zsh' >> /etc/default/useradd
    fi
    usermod -s /usr/bin/zsh root
    systemctl enable --now docker
%{ if gitlab_admin_enabled ~}
    usermod -aG docker ${gitlab_admin_username}
    install -d -m 700 -o ${gitlab_admin_username} -g ${gitlab_admin_username} /home/${gitlab_admin_username}/.ssh
%{ endif ~}
%{ if host_hardening_enabled ~}
    sysctl --system
    sshd -t
    systemctl reload ssh
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
    ufw default deny incoming
    ufw default allow outgoing
%{ if length(host_hardening_ufw_ssh_source_ips) > 0 ~}
%{ for ip in host_hardening_ufw_ssh_source_ips ~}
    ufw allow from ${ip} to any port 22 proto tcp
    ufw allow from ${ip} to any port 2424 proto tcp
%{ endfor ~}
%{ else ~}
    ufw allow 22/tcp
    ufw allow 2424/tcp
%{ endif ~}
    ufw allow 80/tcp
    ufw allow 443/tcp
%{ if host_hardening_ufw_enable_dns ~}
    ufw allow 53/tcp
    ufw allow 53/udp
%{ endif ~}
%{ if host_hardening_ufw_enable_node_exporter ~}
    ufw allow 9100/tcp
%{ endif ~}
%{ if host_hardening_ufw_enable_icmp ~}
    ufw allow in proto icmp
%{ endif ~}
    ufw --force enable
    systemctl enable --now fail2ban
%{ if host_hardening_unattended_upgrades ~}
    systemctl enable --now unattended-upgrades
%{ endif ~}
%{ endif ~}
    install -m 0700 -d /opt/gitlab/traefik/certs
    install -m 0700 -d /opt/gitlab/postgres/data
    chown 999:999 /opt/gitlab/postgres/data
    install -m 0755 -d /opt/gitlab/data/config /opt/gitlab/data/logs /opt/gitlab/data/gitlab
%{ if backup_enabled ~}
    install -m 0755 -d /opt/gitlab/docs
    install -m 0750 -d /opt/gitlab/backups /opt/gitlab/scripts
    chown root:root /opt/gitlab/backups
%{ endif ~}
%{ if runner_enabled ~}
    install -m 0700 -d /opt/gitlab/gitlab-runner
%{ endif ~}
%{ if runner_autoregister ~}
    install -m 0750 -d /opt/gitlab/scripts
    nohup /opt/gitlab/scripts/gitlab-runner-autoregister.sh >>/var/log/gitlab-runner-autoregister.log 2>&1 &
%{ endif ~}
%{ if plantuml_enabled ~}
    install -m 0750 -d /opt/gitlab/scripts
    nohup /opt/gitlab/scripts/gitlab-plantuml-enable.sh >>/var/log/gitlab-plantuml-enable.log 2>&1 &
%{ endif ~}
%{ if renovate_enabled ~}
    install -m 0755 -d /opt/gitlab/renovate/logs /opt/gitlab/renovate/db
%{ endif ~}
%{ if artifacts_enabled ~}
    install -m 0750 -d /opt/gitlab/artifacts/data
%{ endif ~}
%{ if registry_enabled ~}
    install -m 0750 -d /opt/gitlab/registry/data /opt/gitlab/registry/certs
    touch /opt/gitlab/registry/certs/.gitkeep
%{ endif ~}
%{ if terraform_enabled ~}
    install -m 0750 -d /opt/gitlab/data/terraform/state
%{ endif ~}
    cd /opt/gitlab
    docker compose pull
    docker compose up -d
%{ if runner_buildah_enabled ~}
    docker run --privileged --rm tonistiigi/binfmt --install all
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq qemu-user-static binfmt-support || true
%{ endif ~}
    echo "=== finished $(date -Is) ==="
