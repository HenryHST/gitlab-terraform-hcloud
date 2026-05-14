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

  - path: /usr/local/lib/gitlab-terraform/clear_letsencrypt_auto_enabled.py
    permissions: "0644"
    owner: root:root
    content: |
      #!/usr/bin/env python3
      """Persist letsencrypt.auto_enabled=false in gitlab-secrets.json (no other keys removed)."""
      import json
      from pathlib import Path

      def main() -> None:
          p = Path("/etc/gitlab/gitlab-secrets.json")
          if not p.is_file():
              return
          try:
              d = json.loads(p.read_text(encoding="utf-8"))
          except json.JSONDecodeError:
              return
          lec = dict(d.get("letsencrypt") or {})
          lec["auto_enabled"] = False
          d["letsencrypt"] = lec
          p.write_text(json.dumps(d, indent=2) + "\n", encoding="utf-8")

      if __name__ == "__main__":
          main()

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
      mkdir -p /var/lib/gitlab-terraform
      # Strip prior assignments so image/Hetzner defaults cannot override appended block (journal showed LE still running after append-only).
      sed -i '/^[[:space:]]*external_url[[:space:]]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*letsencrypt\['enable'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*letsencrypt\["enable"\]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*letsencrypt\['acme_staging'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*letsencrypt\["acme_staging"\]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*letsencrypt\['contact_emails'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*letsencrypt\["contact_emails"\]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*nginx\['redirect_http_to_https'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*nginx\["redirect_http_to_https"\]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*nginx\['listen_https'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*nginx\["listen_https"\]/d' /etc/gitlab/gitlab.rb
      sed -i "/^[[:space:]]*letsencrypt\['auto_enabled'\]/d" /etc/gitlab/gitlab.rb
      sed -i '/^[[:space:]]*letsencrypt\["auto_enabled"\]/d' /etc/gitlab/gitlab.rb
%{ if gitlab_letsencrypt_enabled }
      {
        echo ""
        echo "# --- gitlab-terraform: integrated Let's Encrypt ---"
        echo "external_url 'https://${gitlab_fqdn}'"
        echo "letsencrypt['enable'] = true"
        echo "letsencrypt['contact_emails'] = ['${letsencrypt_email}']"
        echo "letsencrypt['acme_staging'] = false"
      } >> /etc/gitlab/gitlab.rb
%{ else }
      {
        echo ""
        echo "# --- gitlab-terraform: disable integrated Let's Encrypt (first boot) ---"
        echo "external_url 'http://${gitlab_fqdn}'"
        echo "letsencrypt['enable'] = false"
        echo "letsencrypt['auto_enabled'] = false"
        echo "letsencrypt['acme_staging'] = false"
        echo "nginx['redirect_http_to_https'] = false"
        echo "nginx['listen_https'] = false"
      } >> /etc/gitlab/gitlab.rb
      python3 /usr/local/lib/gitlab-terraform/clear_letsencrypt_auto_enabled.py
%{ endif }
      gitlab-ctl reconfigure
      touch /var/lib/gitlab-terraform/.bootstrap-done

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
      RemainAfterExit=yes

      [Install]
      WantedBy=multi-user.target

runcmd:
  - [systemctl, daemon-reload]
  - [systemctl, enable, gitlab-terraform-bootstrap.service]
  - [bash, -lc, "nohup /usr/local/sbin/gitlab-terraform-schedule-bootstrap.sh &"]
