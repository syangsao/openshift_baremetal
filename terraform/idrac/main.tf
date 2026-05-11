variable "iDRAC_bootstrap" { type = string }
variable "iDRAC_masters" { type = list(string) }
variable "iDRAC_workers" { type = list(string) }
variable "iDRAC_username" { type = string }
variable "iDRAC_password" { type = string }
variable "iso_url" { type = string }

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
      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}'         channel setcap 1 user 4

      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}'         ispset name "VirtualMedia.CDROM.ImageName" value "${var.iso_url}"

      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}'         raw 0x3a 0x01 0x04 0x02 0x00

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
      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}'         chassis bootdev cdrom

      ipmitool -H ${each.value} -U ${var.iDRAC_username} -P '${var.iDRAC_password}'         chassis power cycle

      echo "Node ${each.value} rebooting with virtual media"
    EOT
  }
}

output "idrac_status" {
  description = "iDRAC virtual media status"
  value       = "ISO mounted and boot order set for all ${length(local.all_idracs)} nodes"
}
