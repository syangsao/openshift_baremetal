output "cluster_fqdn" {
  description = "Fully qualified domain name of the cluster"
  value       = "${var.cluster_name}.${var.base_domain}"
}

output "api_url" {
  description = "API server URL"
  value       = "https://api.${var.cluster_name}.${var.base_domain}:6443"
}

output "console_url" {
  description = "OpenShift Web Console URL"
  value       = "https://console-openshift-console.apps.${var.cluster_name}.${var.base_domain}"
}

output "bootstrap_ip" {
  description = "Bootstrap node IP"
  value       = var.bootstrap_ip
}

output "master_ips" {
  description = "Master node IPs"
  value       = var.master_ips
}

output "worker_ips" {
  description = "Worker node IPs"
  value       = var.worker_ips
}

output "lb_ip" {
  description = "Load balancer IP"
  value       = var.lb_ip
}

output "dns_server_ip" {
  description = "DNS server IP"
  value       = var.dns_server_ip
}

output "provisioner_ip" {
  description = "Provisioner/installer host IP"
  value       = var.provisioner_ip
}

output "haproxy_config" {
  description = "Path to generated HAProxy configuration"
  value       = var.haproxy_config_path
}
