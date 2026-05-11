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

variable "lb_server" {
  description = "Load balancer server IP"
  type        = string
}

variable "ssh_key" {
  description = "SSH public key for node access"
  type        = string
}

locals {
  cluster_fqdn = "${var.cluster_name}.${var.base_domain}"
  haproxy_cfg  = templatefile("${path.module}/haproxy.cfg.tpl", {
    bootstrap_ip = var.bootstrap_ip
    master_ips   = var.master_ips
    worker_ips   = var.worker_ips
  })
}

# Write the rendered HAProxy config to disk
resource "local_file" "haproxy_config" {
  content  = local.haproxy_cfg
  filename = "${path.module}/haproxy.cfg"

  file_permission = "0644"
}

# Deploy HAProxy to the load balancer host
resource "null_resource" "haproxy_deploy" {
  depends_on = [local_file.haproxy_config]

  triggers = {
    config_hash = md5(local.haproxy_cfg)
  }

  provisioner "file" {
    source      = "${path.module}/haproxy.cfg"
    destination = "/etc/haproxy/haproxy.cfg"

    connection {
      host        = var.lb_server
      type        = "ssh"
      user        = "core"
      private_key = "~/.ssh/id_ed25519"
    }
  }

  provisioner "remote-exec" {
    connection {
      host        = var.lb_server
      type        = "ssh"
      user        = "core"
      private_key = "~/.ssh/id_ed25519"
    }

    inline = [
      "sudo dnf install -y haproxy",
      "sudo haproxy -c -f /etc/haproxy/haproxy.cfg",
      "sudo systemctl enable --now haproxy",
      "sudo firewall-cmd --permanent --add-port=6443/tcp",
      "sudo firewall-cmd --permanent --add-port=22623/tcp",
      "sudo firewall-cmd --permanent --add-port=443/tcp",
      "sudo firewall-cmd --reload",
      "echo 'HAProxy installed and configured'"
    ]
  }
}
