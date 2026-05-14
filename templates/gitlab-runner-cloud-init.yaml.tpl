#cloud-config
# GitLab Runner per offizieller manueller Linux-Installation (.deb):
# https://docs.gitlab.com/runner/install/linux-manually/
%{ if install_package }
package_update: true
package_upgrade: false
runcmd:
  - |
    set -eux
    ARCH="$(dpkg --print-architecture)"
    WORK="$(mktemp -d)"
    trap 'rm -rf "$WORK"' EXIT
    cd "$WORK"
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl
    curl -fsSL -o gitlab-runner-helper-images.deb \
      "https://s3.dualstack.us-east-1.amazonaws.com/gitlab-runner-downloads/latest/deb/gitlab-runner-helper-images.deb"
    curl -fsSL -o "gitlab-runner-$${ARCH}.deb" \
      "https://s3.dualstack.us-east-1.amazonaws.com/gitlab-runner-downloads/latest/deb/gitlab-runner-$${ARCH}.deb"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      "./gitlab-runner-helper-images.deb" "./gitlab-runner-$${ARCH}.deb"
    systemctl enable --now gitlab-runner
%{ else }
# gitlab_runner_install_package is false: keine automatische Installation (Runner später selbst einrichten).
runcmd: []
%{ endif }
