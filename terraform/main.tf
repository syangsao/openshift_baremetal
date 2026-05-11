terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"
    }
  }
}

# HAProxy load balancer provisioning
module "haproxy" {
  source = "./haproxy"

  cluster_name  = var.cluster_name
  base_domain   = var.base_domain
  bootstrap_ip  = var.bootstrap_ip
  master_ips    = var.master_ips
  worker_ips    = var.worker_ips
  lb_server     = var.lb_server
  ssh_key       = var.ssh_public_key
}

# DNS server provisioning
module "dns" {
  source = "./dns"

  cluster_name    = var.cluster_name
  base_domain     = var.base_domain
  bootstrap_ip    = var.bootstrap_ip
  master_ips      = var.master_ips
  worker_ips      = var.worker_ips
  lb_ip           = var.lb_ip
  dns_server_ip   = var.dns_server_ip
  ssh_key         = var.ssh_public_key
}

# Network configuration for Dell R630 nodes
module "network" {
  source = "./network"

  cluster_network_cidr = var.cluster_network_cidr
  cluster_network_gw   = var.cluster_network_gw
  dns_server_ip        = var.dns_server_ip
  bootstrap_ip         = var.bootstrap_ip
  master_ips           = var.master_ips
  worker_ips           = var.worker_ips
  ssh_key              = var.ssh_public_key
}

# Dell iDRAC virtual media configuration
module "idrac" {
  source = "./idrac"

  iDRAC_bootstrap = var.iDRAC_bootstrap
  iDRAC_masters   = var.iDRAC_masters
  iDRAC_workers   = var.iDRAC_workers
  iDRAC_username  = var.iDRAC_username
  iDRAC_password  = var.iDRAC_password
  iso_url         = "http://${var.provisioner_ip}:8081/rhcos-live.x86_64.iso"
}
