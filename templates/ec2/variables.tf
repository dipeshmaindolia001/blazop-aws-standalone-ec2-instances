# Variables mirror schema.tfvars.json (config repo).
# Several schema-required values have defaults here so a partial form still plans in the simulation.

variable "aws_region" {
  description = "AWS region (passed by workflow, not part of tfvars)."
  type        = string
  default     = "ap-south-1"
}

variable "request_number" {
  description = "ServiceNow request number (RITMxxxxxxx)."
  type        = string
  default     = null
}

variable "account_id" {
  description = "AWS account ID. When set, Terraform refuses to run against any other account."
  type        = string
  default     = null
}

variable "account_id_sharedservices" {
  description = "Shared services account ID (informational in simulation)."
  type        = string
  default     = null
}

variable "instance_count" {
  description = "Number of EC2 instances to create."
  type        = number
  default     = 1
}

variable "os_type" {
  description = "Operating system image to deploy."
  type        = string
  validation {
    condition     = contains(["win2016", "win2019", "win2022", "win2023", "win2025", "rhel8", "rhel9", "al2023"], var.os_type)
    error_message = "os_type must be one of win2016, win2019, win2022, win2023, win2025, rhel8, rhel9, al2023."
  }
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "ami_id" {
  description = "Optional custom AMI ID. If null, AMI is selected from os_type."
  type        = string
  default     = null
}

variable "key_name" {
  description = "EC2 key pair name."
  type        = string
  default     = null
}

variable "subnet_type" {
  description = "Subnet tier. Simulation uses the default VPC, so this is recorded as a tag only."
  type        = string
  default     = "public"
}

variable "availability_zone" {
  description = "Specific AZ, or null for automatic selection."
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Optional subnet ID; bypasses subnet discovery."
  type        = string
  default     = null
}

variable "root_disk_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 40
}

variable "root_disk_type" {
  description = "Root EBS volume type."
  type        = string
  default     = "gp3"
}

variable "root_disk_iops" {
  description = "Root volume IOPS (used only for gp3/io1/io2)."
  type        = number
  default     = 3000
}

variable "ebs_volumes" {
  description = "Additional EBS volumes. Key = device name (e.g. /dev/sdf)."
  type = map(object({
    size        = number
    type        = optional(string, "gp3")
    encrypted   = optional(bool, true)
    iops        = optional(number)
    snapshot_id = optional(string)
  }))
  default = {}
}

variable "schedule" {
  description = "Schedule tag value."
  type        = string
  default     = "none"
}

variable "backup_plan" {
  description = "Backup plan tag value."
  type        = string
  default     = "ec2"
}

variable "user_data_file" {
  description = "File name inside userdata/ of this repo."
  type        = string
  default     = null
}

variable "create_iam_instance_profile" {
  description = "Create a new IAM role + instance profile."
  type        = bool
  default     = true
}

variable "iam_instance_profile" {
  description = "Existing instance profile name (used when create_iam_instance_profile = false)."
  type        = string
  default     = null
}

variable "iam_role_policies" {
  description = "Map of name => policy ARN attached to the generated role."
  type        = map(string)
  default     = {}
}

variable "security_group_ids" {
  description = "Existing security groups to attach."
  type        = list(string)
  default     = []
}

variable "ingress_rules" {
  description = "Ingress rules for the auto-created security group."
  type = map(object({
    cidr_ipv4                    = optional(string)
    description                  = optional(string)
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = optional(string, "tcp")
    prefix_list_id               = optional(string)
    referenced_security_group_id = optional(string)
    tags                         = optional(map(string), {})
  }))
  default = {}
}

variable "additional_tags" {
  description = "Extra tags for the instance and attached resources."
  type        = map(string)
  default     = {}
}

variable "instance_name" {
  description = "Name tag value."
  type        = string
  default     = null
}

variable "create_default_sg" {
  description = "Create a dedicated security group."
  type        = bool
  default     = true
}

variable "platform" {
  description = "linux or windows."
  type        = string
  validation {
    condition     = contains(["linux", "windows"], var.platform)
    error_message = "platform must be linux or windows."
  }
}

variable "default_tags" {
  description = "Mandatory organisational tags (App, Environment, Capability, CostCenter, Source)."
  type        = map(string)
  default     = {}
}
