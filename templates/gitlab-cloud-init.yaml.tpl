#cloud-config
# Hetzner 001_onboot appends to /root/.bashrc during cloud_final. "enable" alone may not start our unit if
# multi-user.target is already active. A small background script waits until hooks exist, then starts the oneshot.
write_files:
  - path: /usr/local/sbin/gitlab-terraform-schedule-bootstrap.sh
    permissions: "0755"
    owner: root:root
    content: |
      #!/bin/bash
      set -euo pipefail
      if [[ -f /var/lib/gitlab-terraform/.bootstrap-done ]]; then
        exit 0
      fi
      for _ in $(seq 1 90); do
        if grep -qE 'gitlab_setup|hcloud/gitlab_setup' /root/.bashrc 2>/dev/null; then
          break
        fi
        sleep 2
      done
      sleep 5
      systemctl start gitlab-terraform-bootstrap.service

  - path: /usr/local/sbin/gitlab-terraform-bootstrap.sh
    permissions: "0755"
    owner: root:root
    content: |
      #!/bin/bash
      set -euo pipefail
      sleep ${bootstrap_wait}
      for f in /root/.bashrc /root/.profile; do
        if [[ -f "$f" ]]; then
          sed -i '#gitlab_setup#d' "$f"
        fi
      done
      if [[ -f /opt/hcloud/gitlab_setup.sh ]]; then
        printf '%s\n' '#!/bin/sh' 'exit 0' > /opt/hcloud/gitlab_setup.sh
        chmod 0755 /opt/hcloud/gitlab_setup.sh
      fi
      sed -i "s|^external_url .*|external_url 'https://${gitlab_fqdn}'|" /etc/gitlab/gitlab.rb
      if ! grep -qF "letsencrypt['enable'] = true" /etc/gitlab/gitlab.rb; then
        {
          echo ""
          echo "letsencrypt['enable'] = true"
          echo "letsencrypt['contact_emails'] = ['${letsencrypt_email}']"
        } >> /etc/gitlab/gitlab.rb
      fi
      gitlab-ctl reconfigure

  - path: /etc/systemd/system/gitlab-terraform-bootstrap.service
    permissions: "0644"
    owner: root:root
    content: |
      [Unit]
      Description=GitLab Terraform bootstrap after Hetzner 001_onboot hooks exist
      After=network-online.target
      Wants=network-online.target
      ConditionPathExists=!/var/lib/gitlab-terraform/.bootstrap-done

      [Service]
      Type=oneshot
      ExecStartPre=/usr/bin/mkdir -p /var/lib/gitlab-terraform
      ExecStart=/usr/local/sbin/gitlab-terraform-bootstrap.sh
      ExecStartPost=/usr/bin/touch /var/lib/gitlab-terraform/.bootstrap-done
      RemainAfterExit=yes

      [Install]
      WantedBy=multi-user.target

runcmd:
  - [systemctl, daemon-reload]
  - [systemctl, enable, gitlab-terraform-bootstrap.service]
  - [bash, -lc, "nohup /usr/local/sbin/gitlab-terraform-schedule-bootstrap.sh &"]
