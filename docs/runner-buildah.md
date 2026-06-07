# GitLab Runner: Buildah-Profile (Docker Compose)

Three instance runners in the same Compose stack for container image builds with [Buildah](https://buildah.io/). Pipelines select the profile via `tags:`.

## Terraform

| Variable | Default | Role |
|----------|---------|------|
| `gitlab_docker_runner_enabled` | `false` | Must be `true` |
| `gitlab_docker_runner_buildah_enabled` | `false` | Opt-in: three Buildah runners instead of one generic runner |
| `gitlab_docker_runner_buildah_default_image` | `quay.io/buildah/stable` | Empfohlenes Job-Image in CI (`.gitlab-ci.yml`); **nicht** in `config.toml` |
| `gitlab_docker_runner_autoregister` | `true` | **Required** with empty `gitlab_docker_runner_token` (three `glrt-…` tokens) |

Example:

```hcl
gitlab_docker_runner_enabled              = true
gitlab_docker_runner_buildah_enabled      = true
gitlab_docker_runner_autoregister         = true
gitlab_docker_runner_token                = ""
gitlab_docker_runner_buildah_default_image = "quay.io/buildah/stable"
```

When `gitlab_docker_runner_buildah_enabled = true`, the generic single runner (`gitlab_docker_runner_tags = ["docker"]`) is **not** registered — only the three Buildah profiles below.

## Runner profiles

| Modus | Runner tag | `config.toml` | Buildah CI variables |
|-------|------------|---------------|----------------------|
| Rootless single-arch | `buildah-rootless` | `run_untagged = true`, `privileged = false`, `security_opt` | `STORAGE_DRIVER=vfs`, `BUILDAH_ISOLATION=chroot` |
| Privileged | `buildah-privileged` | `run_untagged = false`, `privileged = true` | `STORAGE_DRIVER=overlay` (optional) |
| Rootless multi-arch | `buildah-multiarch` | `run_untagged = false`, `privileged = false`, `security_opt` | same as rootless + host QEMU/binfmt |

Tags werden bei der API-Registrierung (`POST /api/v4/user/runners`, Form-Feld `tag_list`) gesetzt — **nicht** in `config.toml`. Job-Images kommen aus der CI-Pipeline, nicht aus dem Runner-Default.

Beispiel `config.toml` (Tokens und URL aus Autoregister):

```toml
concurrent = 12
check_interval = 0
shutdown_timeout = 0

[[runners]]
  name = "buildah-rootless"
  url = "https://gitlab.example.com"
  token = "glrt-…"
  executor = "docker"
  run_untagged = true
  [runners.docker]
    tls_verify = false
    privileged = false
    security_opt = ["seccomp=unconfined", "apparmor=unconfined"]
    volumes = ["/cache"]

[[runners]]
  name = "buildah-privileged"
  url = "https://gitlab.example.com"
  token = "glrt-…"
  executor = "docker"
  run_untagged = false
  [runners.docker]
    tls_verify = false
    privileged = true
    volumes = ["/cache"]

[[runners]]
  name = "buildah-multiarch"
  url = "https://gitlab.example.com"
  token = "glrt-…"
  executor = "docker"
  run_untagged = false
  [runners.docker]
    tls_verify = false
    privileged = false
    security_opt = ["seccomp=unconfined", "apparmor=unconfined"]
    volumes = ["/cache"]
```

Host bootstrap (when Buildah enabled): `tonistiigi/binfmt --install all` and `qemu-user-static` for cross-arch builds.

`concurrent` in `config.toml` is at least `3 × 4 = 12` when Buildah is enabled (override with `gitlab_docker_runner_concurrent` if higher).

## Checklist after apply

- [ ] **Admin → CI/CD → Runners:** three instance runners (`buildah-rootless`, `buildah-multiarch`, `buildah-privileged`)
- [ ] `docker compose exec gitlab-runner cat /etc/gitlab-runner/config.toml` — three `[[runners]]` blocks
- [ ] `/var/log/gitlab-runner-autoregister.log` — `runner autoregister ok (buildah x3)`
- [ ] Test pipeline with example [`gitlab-ci-buildah.yml.example`](examples/gitlab-ci-buildah.yml.example)

## Multi-Arch troubleshooting

| Symptom | Action |
|---------|--------|
| `exec format error` | Host: `docker run --privileged --rm tonistiigi/binfmt --install all`; use tag `buildah-multiarch` |
| `Manifest push 401` | Registry login in CI `before_script` (`docker login` / `buildah login` to `registry.<zone>`) |
| Job stuck / pending | Job `tags:` must match runner tag exactly |
| Rootless build fails | Use `buildah-rootless` or `buildah-multiarch`; set `STORAGE_DRIVER=vfs`, `BUILDAH_ISOLATION=chroot` |

## Migration from single runner

1. Remove old instance runner in **Admin → CI/CD → Runners** (optional).
2. Set `gitlab_docker_runner_buildah_enabled = true`, empty token, `autoregister = true`.
3. Re-apply or re-run `/opt/gitlab/scripts/gitlab-runner-autoregister.sh` on the host.
4. Update `.gitlab-ci.yml` `tags:` to one of the Buildah tags.

See also: [GitLab Runner im Compose-Stack](gitlab-install-modes.md#gitlab-runner-im-compose-stack-autoregister).
