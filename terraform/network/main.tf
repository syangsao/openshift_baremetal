variable "cluster_network_cidr" { type = string }
variable "cluster_network_gw" { type = string }
variable "dns_server_ip" { type = string }
variable "bootstrap_ip" { type = string }
variable "master_ips" { type = list(string) }
variable "worker_ips" { type = list(string) }
variable "ssh_key" { type = string }

locals {
  all_nodes = setunion([var.bootstrap_ip], set(var.master_ips), set(var.worker_ips))
}

resource "null_resource" "network_config" {
  for_each = local.all_nodes

  provisioner "remote-exec" {
    connection {
      host        = each.value
      type        = "ssh"
      user        = "core"
      private_key = "~/.ssh/id_ed25519"
    }

    inline = [
      <<-EOT
        # Configure NetworkManager bridge for cluster networking
        nmcli con add type bridge con-name cluster-bridge ifname br0 ipv4.method manual           ipv4.addresses ${each.value}/24 ipv4.gateway ${var.cluster_network_gw} ipv4.dns ${var.dns_server_ip}

        nmcli con mod cluster-bridge bridge.stp false

        # Enslave physical interface
        nmcli con add type ethernet slave-type bridge ifname eno1 con-name br0-en1 master br0

        # Activate
        nmcli con up cluster-bridge
        echo "Network configured for ${each.value}"
      EOT
    ]
  }
}
