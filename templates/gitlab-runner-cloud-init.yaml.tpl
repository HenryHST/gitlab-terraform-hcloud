#cloud-config
# GitLab Runner per offizieller manueller Linux-Installation (.deb):
# https://docs.gitlab.com/runner/install/linux-manually/
%{ if install_package }
package_update: true
package_upgrade: false
runcmd:
  - |
    set -eux
    LOG=/var/log/gitlab-runner-terraform-bootstrap.log
    exec >>"$LOG" 2>&1
    echo "=== gitlab-runner bootstrap $(date -Is) ==="
    ARCH="$(dpkg --print-architecture)"
    case "$ARCH" in
      amd64|arm64|i386|ppc64el|s390x|riscv64|loong64) DEB_ARCH="$ARCH" ;;
      armhf|armel) DEB_ARCH="arm" ;;
      *) DEB_ARCH="$ARCH" ;;
    esac
    echo "dpkg architecture=$ARCH deb_suffix=$DEB_ARCH"
    WORK="$(mktemp -d)"
    trap 'rm -rf "$WORK"' EXIT
    cd "$WORK"
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl
    curl -fsSL -o gitlab-runner-helper-images.deb \
      "https://s3.dualstack.us-east-1.amazonaws.com/gitlab-runner-downloads/latest/deb/gitlab-runner-helper-images.deb"
    curl -fsSL -o "gitlab-runner_$${DEB_ARCH}.deb" \
      "https://s3.dualstack.us-east-1.amazonaws.com/gitlab-runner-downloads/latest/deb/gitlab-runner_$${DEB_ARCH}.deb"
    if ! dpkg -i ./gitlab-runner-helper-images.deb "./gitlab-runner_$${DEB_ARCH}.deb"; then
      apt-get install -f -y -qq
      dpkg -i ./gitlab-runner-helper-images.deb "./gitlab-runner_$${DEB_ARCH}.deb"
    fi
    systemctl daemon-reload
    systemctl enable --now gitlab-runner
    echo "=== finished $(date -Is) dpkg=$(dpkg-query -W -f='$${Status}' gitlab-runner 2>/dev/null || echo missing) active=$(systemctl is-active gitlab-runner 2>/dev/null || echo n/a) ==="
%{ else }
# gitlab_runner_install_package is false: keine automatische Installation (Runner später selbst einrichten).
runcmd: []
%{ endif }
