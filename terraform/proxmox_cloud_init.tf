# Upload gitlab-docker-cloud-init.yaml.tpl to Proxmox snippets for cicustom (see README "GitLab auf Proxmox").

resource "local_sensitive_file" "proxmox_gitlab_cloud_init" {
  count = local.proxmox_gitlab_docker ? 1 : 0

  content         = local.gitlab_docker_user_data
  filename        = "${path.module}/.generated/${var.proxmox_cloud_init_snippet_name}"
  file_permission = "0600"
}

resource "null_resource" "proxmox_upload_cloud_init_snippet" {
  count = local.proxmox_gitlab_docker ? 1 : 0

  triggers = {
    content_sha = sha256(local.gitlab_docker_user_data)
    node        = var.proxmox_node
    storage     = var.proxmox_snippet_storage
    filename    = var.proxmox_cloud_init_snippet_name
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      curl -sfS${var.pm_tls_insecure ? " -k" : ""} -X POST \
        -H "Authorization: PVEAPIToken=${var.proxmox_api_token_id}=${var.proxmox_api_token}" \
        -F "content=@${local_sensitive_file.proxmox_gitlab_cloud_init[0].filename}" \
        "${trimsuffix(var.proxmox_api_url, "/")}/nodes/${var.proxmox_node}/storage/${var.proxmox_snippet_storage}/upload?content=snippets&filename=snippets%2F${var.proxmox_cloud_init_snippet_name}"
    EOT
  }

  depends_on = [local_sensitive_file.proxmox_gitlab_cloud_init]
}
