variable "cluster_name" { type = string }
variable "base_domain" { type = string }
variable "bootstrap_ip" { type = string }
variable "master_ips" { type = list(string) }
variable "worker_ips" { type = list(string) }
variable "lb_ip" { type = string }
variable "dns_server_ip" { type = string }
variable "ssh_key" { type = string }

locals {
  cluster_fqdn = "${var.cluster_name}.${var.base_domain}"
}

resource "null_resource" "dns_zone" {
  triggers = {
    master_ips = join(",", var.master_ips)
    worker_ips = join(",", var.worker_ips)
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat > ${path.module}/forward.zone << 'EOF'
$ORIGIN ${local.cluster_fqdn}.
$TTL 300
@ IN SOA ns1 ${var.base_domain}. (
      2026051101
      3600
      1800
      604800
      300 )
@ IN NS ns1.${var.base_domain}.
api IN A ${var.lb_ip}
api-int IN A ${var.lb_ip}
*.apps IN A ${var.lb_ip}
bootstrap IN A ${var.bootstrap_ip}
${''.join([f'master{i} IN A {ip}' for i, ip in enumerate(var.master_ips)])}
${''.join([f'worker{i} IN A {ip}' for i, ip in enumerate(var.worker_ips)])}
EOF
      echo "DNS zone file generated"
    EOT
  }
}

resource "null_resource" "dns_deploy" {
  depends_on = [null_resource.dns_zone]

  provisioner "remote-exec" {
    connection {
      host        = var.dns_server_ip
      type        = "ssh"
      user        = "core"
      private_key = "~/.ssh/id_ed25519"
    }

    inline = [
      "sudo dnf install -y bind bind-utils",
      "sudo cp ${path.module}/forward.zone /var/named/${local.cluster_fqdn}.zone",
      "sudo chown named:named /var/named/${local.cluster_fqdn}.zone",
      "sudo systemctl enable --now named",
      "sudo firewall-cmd --permanent --add-port=53/tcp --add-port=53/udp",
      "sudo firewall-cmd --reload",
      "dig @localhost api.${local.cluster_fqdn}",
      "echo 'BIND DNS server installed and configured'"
    ]
  }
}
