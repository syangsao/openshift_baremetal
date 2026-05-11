variable "cluster_name" {
  description = "OpenShift cluster name"
  type        = string
  default     = "mycluster"
}

variable "base_domain" {
  description = "Base domain for the cluster"
  type        = string
  default     = "example.com"
}

variable "cluster_network_cidr" {
  description = "Cluster network CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "cluster_network_gw" {
  description = "Cluster network gateway"
  type        = string
  default     = "10.0.1.1"
}

variable "provisioner_ip" {
  description = "Installer/provisioner host IP"
  type        = string
  default     = "10.0.0.10"
}

variable "bootstrap_ip" {
  description = "Bootstrap node IP"
  type        = string
  default     = "10.0.1.11"
}

variable "master_ips" {
  description = "Master node IPs"
  type        = list(string)
  default     = ["10.0.1.12", "10.0.1.13", "10.0.1.14"]
}

variable "worker_ips" {
  description = "Worker node IPs"
  type        = list(string)
  default     = ["10.0.1.21", "10.0.1.22"]
}

variable "lb_ip" {
  description = "Load balancer VIP"
  type        = string
  default     = "10.0.0.12"
}

variable "lb_server" {
  description = "Load balancer server IP (can differ from VIP)"
  type        = string
  default     = "10.0.0.12"
}

variable "dns_server_ip" {
  description = "DNS server IP"
  type        = string
  default     = "10.0.0.11"
}

variable "ssh_public_key" {
  description = "SSH public key for node access"
  type        = string
}

variable "haproxy_config_path" {
  description = "Path to HAProxy configuration template"
  type        = string
  default     = "${path.module}/haproxy/haproxy.cfg"
}

# Dell iDRAC configuration
variable "iDRAC_bootstrap" {
  description = "iDRAC IP for bootstrap Dell R630"
  type        = string
}

variable "iDRAC_masters" {
  description = "iDRAC IPs for master Dell R630s"
  type        = list(string)
}

variable "iDRAC_workers" {
  description = "iDRAC IPs for worker Dell R630s"
  type        = list(string)
}

variable "iDRAC_username" {
  description = "iDRAC username"
  type        = string
  default     = "root"
}

variable "iDRAC_password" {
  description = "iDRAC password"
  type        = string
  sensitive   = true
}

# Derived values
locals {
  all_nodes   = setunion([var.bootstrap_ip], set(var.master_ips), set(var.worker_ips))
  all_masters = set(var.master_ips)
  all_workers = set(var.worker_ips)
  cluster_fqdn = "${var.cluster_name}.${var.base_domain}"
}
