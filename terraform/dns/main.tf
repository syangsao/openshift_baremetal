variable "cluster_name" {
  description = "OpenShift cluster name"
  type        = string
}

variable "base_domain" {
  description = "Base domain for the cluster"
  type        = string
}

variable "bootstrap_ip" {
  description = "Bootstrap node IP"
  type        = string
}

variable "master_ips" {
  description = "Master node IPs"
  type        = list(string)
}

variable "worker_ips" {
  description = "Worker node IPs"
  type        = list(string)
}

variable "lb_ip" {
  description = "Load balancer VIP"
  type        = string
}

variable "dns_server_ip" {
  description = "DNS server IP"
  type        = string
}

variable "ssh_key" {
  description = "SSH public key for node access"
  type        = string
}

locals {
  cluster_fqdn = "${var.cluster_name}.${var.base_domain}"
  zone_file    = templatefile("${path.module}/forward.zone.tpl", {
    cluster_fqdn = local.cluster_fqdn
    base_domain  = var.base_domain
    bootstrap_ip = var.bootstrap_ip
    lb_ip        = var.lb_ip
    master_ips   = var.master_ips
    worker_ips   = var.worker_ips
  })
}

# Write the rendered zone file to disk
resource "local_file" "dns_zone" {
  content  = local.zone_file
  filename = "${path.module}/${local.cluster_fqdn}.zone"

  file_permission = "0644"
}

# Deploy BIND DNS server
resource "null_resource" "dns_deploy" {
  depends_on = [local_file.dns_zone]

  triggers = {
    zone_hash = md5(local.zone_file)
  }

  provisioner "file" {
    source      = "${path.module}/${local.cluster_fqdn}.zone"
    destination = "/var/named/${local.cluster_fqdn}.zone"

    connection {
      host        = var.dns_server_ip
      type        = "ssh"
      user        = "core"
      private_key = "~/.ssh/id_ed25519"
    }
  }

  provisioner "remote-exec" {
    connection {
      host        = var.dns_server_ip
      type        = "ssh"
      user        = "core"
      private_key = "~/.ssh/id_ed25519"
    }

    inline = [
      "sudo dnf install -y bind bind-utils",
      "sudo chown named:named /var/named/${local.cluster_fqdn}.zone",
      "sudo systemctl enable --now named",
      "sudo firewall-cmd --permanent --add-port=53/tcp --add-port=53/udp",
      "sudo firewall-cmd --reload",
      "dig @localhost api.${local.cluster_fqdn}",
      "echo 'BIND DNS server installed and configured'"
    ]
  }
}
