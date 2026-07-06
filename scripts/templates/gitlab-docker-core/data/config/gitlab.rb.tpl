## Managed by pve-secure-gitlab-lxc.sh — edit on host: /opt/gitlab/data/config/gitlab.rb
## Then: docker compose exec gitlab gitlab-ctl reconfigure

external_url '${EXTERNAL_URL_SCHEME}://${GITLAB_FQDN}'

# Traefik terminates TLS; Omnibus HTTP only
nginx['listen_port'] = 80
nginx['listen_https'] = false
${ACME_GITLAB_RB_BLOCK}

# https://docs.gitlab.com/install/docker/configuration/#expose-gitlab-on-different-ports
gitlab_rails['gitlab_shell_ssh_port'] = 2424
gitlab_rails['display_initial_root_password'] = false

# External PostgreSQL (docker service postgres on socket_proxy)
postgresql['enable'] = false
gitlab_rails['db_adapter'] = 'postgresql'
gitlab_rails['db_encoding'] = 'unicode'
gitlab_rails['db_host'] = 'postgres'
gitlab_rails['db_port'] = 5432
gitlab_rails['db_username'] = 'gitlab'
gitlab_rails['db_password'] = '${POSTGRES_PASSWORD}'
gitlab_rails['db_database'] = 'gitlabhq_production'

gitlab_pages['enable'] = false
gitlab_rails['gitlab_default_theme'] = ${GITLAB_THEME_ID}
gitlab_rails['gitlab_default_color_mode'] = ${GITLAB_COLOR_MODE}
gitlab_rails['time_zone'] = '${GITLAB_TIME_ZONE}'
gitlab_rails['gitlab_default_can_create_group'] = true
gitlab_rails['gitlab_username_changing_enabled'] = true
gitlab_rails['webhook_timeout'] = 10
gitlab_rails['artifacts_enabled'] = false
gitlab_rails['gitlab_signup_enabled'] = ${GITLAB_SIGNUP_ENABLED}
gitlab_rails['smtp_enable'] = false
