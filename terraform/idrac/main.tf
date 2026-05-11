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

variable "iso_url" {
  description = "URL of the RHCOS boot ISO"
  type        = string
}

locals {
  all_idracs = setunion(
    [var.iDRAC_bootstrap],
    set(var.iDRAC_masters),
    set(var.iDRAC_workers)
  )
}

# Mount ISO via virtual media on all iDRACs
resource "null_resource" "idrac_mount_iso" {
  for_each = local.all_idracs

  provisioner "local-exec" {
    command = <<-EOT
      echo "Mounting ISO on iDRAC ${each.value}"
      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}' \
        channel setcap 1 user 4
      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}' \
        raw 0x01 0x3c 0x05 0x02 0x01 0x10
      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}' \
        raw 0x01 0x3c 0x05 0x02 0x01 0x11 $(printf '%%02x%%02x%%02x%%02x' 0x00 0x00 0x00 0x00)
      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}' \
        raw 0x01 0x3c 0x05 0x02 0x01 0x12 $(printf '%%02x' $(echo -n '${var.iso_url}' | wc -c))
      echo "ISO mounted on ${each.value}"
    EOT
  }
}

# Set boot order to CD-ROM and reboot
resource "null_resource" "idrac_boot_order" {
  for_each = local.all_idracs
  depends_on = [null_resource.idrac_mount_iso]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Setting boot order for iDRAC ${each.value}"
      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}' \
        chassis bootdev cdrom
      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}' \
        chassis bootdev set BiosBootSeq CDROM
      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}' \
        chassis power cycle
      echo "Node ${each.value} rebooting with virtual media"
    EOT
  }
}

# Unmount ISO after installation completes
resource "null_resource" "idrac_unmount_iso" {
  for_each = local.all_idracs
  depends_on = [null_resource.idrac_boot_order]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Unmounting ISO on iDRAC ${each.value}"
      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}' \
        raw 0x01 0x3c 0x05 0x02 0x01 0x10
      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}' \
        raw 0x01 0x3c 0x05 0x02 0x01 0x11 $(printf '%%02x%%02x%%02x%%02x' 0x00 0x00 0x00 0x00)
      echo "ISO unmounted on ${each.value}"
    EOT
  }
}

output "idrac_status" {
  description = "iDRAC virtual media status"
  value       = "ISO mounted and boot order set for all ${length(local.all_idracs)} nodes"
}
