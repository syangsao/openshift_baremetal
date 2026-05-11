variable "cluster_name" { type = string }
variable "base_domain" { type = string }
variable "bootstrap_ip" { type = string }
variable "master_ips" { type = list(string) }
variable "worker_ips" { type = list(string) }
variable "lb_server" { type = string }
variable "ssh_key" { type = string }

locals {
  cluster_fqdn = "${var.cluster_name}.${var.base_domain}"
}

resource "null_resource" "haproxy_config" {
  triggers = {
    master_ips = join(",", var.master_ips)
    worker_ips = join(",", var.worker_ips)
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat > ${path.module}/haproxy.cfg << 'EOF'
global
    log     /dev/log local0
    log     /dev/log local1 notice
    chroot  /var/lib/haproxy
    stats   socket /run/haproxy/admin.sock mode 660 level admin
    stats   timeout 30s
    user    haproxy
    group   haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    timeout connect 5s
    timeout client  50s
    timeout server  50s

frontend openshift-api
    bind *:6443
    mode tcp
    option tcp-check
    default_backend openshift-api-backend

backend openshift-api-backend
    mode tcp
    balance roundrobin
    option tcp-check
${''.join([f'    server master{i} {ip}:6443 check fall 3 rise 2' for i, ip in enumerate(var.master_ips)])}

frontend openshift-bootstrap
    bind *:22623
    mode tcp
    option tcp-check
    default_backend openshift-bootstrap-backend

backend openshift-bootstrap-backend
    mode tcp
    balance roundrobin
    option tcp-check
    server bootstrap ${var.bootstrap_ip}:22623 check fall 3 rise 2
${''.join([f'    server master{i} {ip}:22623 check fall 3 rise 2' for i, ip in enumerate(var.master_ips)])}

frontend openshift-router
    bind *:443
    mode tcp
    option tcp-check
    default_backend openshift-router-backend

backend openshift-router-backend
    mode tcp
    balance roundrobin
    option tcp-check
${''.join([f'    server worker{i} {ip}:443 check fall 3 rise 2' for i, ip in enumerate(var.worker_ips)])}
EOF

      echo "HAProxy config generated"
    EOT
  }
}

resource "null_resource" "haproxy_deploy" {
  depends_on = [null_resource.haproxy_config]

  provisioner "remote-exec" {
    connection {
      host        = var.lb_server
      type        = "ssh"
      user        = "core"
      private_key = "~/.ssh/id_ed25519"
    }

    inline = [
      "sudo dnf install -y haproxy",
      "sudo cp ${path.module}/haproxy.cfg /etc/haproxy/haproxy.cfg",
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
