# OpenShift UPI Bare Metal Terraform - Makefile
#
# Usage:
#   make init          - Initialize Terraform providers
#   make plan          - Show planned changes
#   make apply         - Apply Terraform configuration
#   make validate      - Validate Terraform configuration
#   make fmt           - Format Terraform files
#   make destroy       - Destroy all provisioned resources
#   make clean         - Remove generated files and state

TFDIR := terraform

.PHONY: init plan apply validate fmt destroy clean

init:
	cd $(TFDIR) && terraform init -upgrade

plan:
	cd $(TFDIR) && terraform plan

apply:
	cd $(TFDIR) && terraform apply -auto-approve

validate:
	cd $(TFDIR) && terraform validate

fmt:
	cd $(TFDIR) && terraform fmt -recursive

destroy:
	cd $(TFDIR) && terraform destroy -auto-approve

clean:
	cd $(TFDIR) && rm -rf .terraform .terraform.lock.hcl haproxy/haproxy.cfg dns/*.zone
	cd $(TFDIR) && terraform state pull > /dev/null 2>&1 || true
