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
      providers:
        docker:
          endpoint: "unix:///var/run/docker.sock"
          exposedByDefault: false
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

  - path: /opt/gitlab/docker-compose.yml
    owner: root:root
    permissions: "0644"
    content: |
      services:
        traefik:
          image: ${traefik_image}
          restart: unless-stopped
          ports:
            - "80:80"
            - "443:443"
          volumes:
            - "/var/run/docker.sock:/var/run/docker.sock:ro"
            - "./traefik:/etc/traefik:ro"
            - "traefik_acme:/letsencrypt"
          command:
            - "--configFile=/etc/traefik/traefik.yml"
          networks:
            - web

        gitlab:
          image: ${gitlab_ce_image}
          restart: unless-stopped
          hostname: "${gitlab_fqdn}"
          shm_size: "256m"
          environment:
            GITLAB_ROOT_PASSWORD: "${gitlab_root_password}"
            GITLAB_OMNIBUS_CONFIG: |
              external_url '${external_url_scheme}://${gitlab_fqdn}'
              nginx['listen_port'] = 80
              nginx['listen_https'] = false
          volumes:
            - "gitlab_config:/etc/gitlab"
            - "gitlab_logs:/var/log/gitlab"
            - "gitlab_data:/var/opt/gitlab"
          networks:
            - web
          labels:
            - "traefik.enable=true"
            - "traefik.docker.network=gitlab_web"
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

      networks:
        web:
          name: gitlab_web

      volumes:
        gitlab_config:
        gitlab_logs:
        gitlab_data:
        traefik_acme:

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
    cd /opt/gitlab
    docker compose pull
    docker compose up -d
    echo "=== finished $(date -Is) ==="
