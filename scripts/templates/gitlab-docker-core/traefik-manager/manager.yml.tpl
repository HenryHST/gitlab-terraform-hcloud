# Pre-seeded by gitlab-docker bootstrap (skipped if manager.yml already exists).
domains:
  - ${DNS_DOMAIN}
cert_resolver: ${TRAEFIK_MANAGER_CERT_RESOLVER}
traefik_api_url: http://traefik:8080
auth_enabled: true
setup_complete: true
must_change_password: false
