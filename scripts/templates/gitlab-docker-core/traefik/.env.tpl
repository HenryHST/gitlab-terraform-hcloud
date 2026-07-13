ABSOLUTE_PATH=/opt/gitlab
TZ=Europe/Berlin
SERVICES_TRAEFIK_LABELS_TRAEFIK_HOST=HOST(`${GITLAB_FQDN}`)
# Hetzner DNS API token (dns.hetzner.com). Lego/Traefik v3.7+ prefers HETZNER_API_TOKEN for the
# Hetzner Cloud DNS API; this project uses the legacy DNS console token → map to HETZNER_API_KEY only.
HETZNER_API_KEY=${HETZNER_API_TOKEN}
ACME_EMAIL=${ACME_EMAIL}
