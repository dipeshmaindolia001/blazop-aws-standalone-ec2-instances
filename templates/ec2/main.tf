locals {
  name = coalesce(var.instance_name, var.request_number, "blazop-ec2")

  # AMI lookup via public SSM parameters (Amazon Linux / Windows)
  ssm_ami_params = {
    al2023  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
    win2016 = "/aws/service/ami-windows-latest/Windows_Server-2016-English-Full-Base"
    win2019 = "/aws/service/ami-windows-latest/Windows_Server-2019-English-Full-Base"
    win2022 = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
    win2023 = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base" # no "2023" release; mapped to 2022
    win2025 = "/aws/service/ami-windows-latest/Windows_Server-2025-English-Full-Base"
  }

  # RHEL via Red Hat owned AMIs
  rhel_name_filter = {
    rhel8 = "RHEL-8.*_HVM-*-x86_64-*"
    rhel9 = "RHEL-9.*_HVM-*-x86_64-*"
  }

  is_rhel = contains(keys(local.rhel_name_filter), var.os_type)

  common_tags = merge(var.additional_tags, {
    RequestNumber = coalesce(var.request_number, "n/a")
    Schedule      = var.schedule
    BackupPlan    = var.backup_plan
    Platform      = var.platform
    OsType        = var.os_type
    SubnetType    = var.subnet_type
    ManagedBy     = "terraform-blazop-simulation"
  })
}

# ---------------------------------------------------------------- AMI
data "aws_ssm_parameter" "ami" {
  count = var.ami_id == null && !local.is_rhel ? 1 : 0
  name  = local.ssm_ami_params[var.os_type]
}

data "aws_ami" "rhel" {
  count       = var.ami_id == null && local.is_rhel ? 1 : 0
  most_recent = true
  owners      = ["309956199498"] # Red Hat

  filter {
    name   = "name"
    values = [local.rhel_name_filter[var.os_type]]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  ami_id = coalesce(
    var.ami_id,
    one(data.aws_ami.rhel[*].id),
    one(data.aws_ssm_parameter.ami[*].insecure_value)
  )
}

# ------------------------------------------------------------- Subnet
data "aws_vpc" "default" {
  count   = var.subnet_id == null ? 1 : 0
  default = true
}

data "aws_subnets" "candidates" {
  count = var.subnet_id == null ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [one(data.aws_vpc.default[*].id)]
  }

  dynamic "filter" {
    for_each = var.availability_zone == null ? [] : [var.availability_zone]
    content {
      name   = "availability-zone"
      values = [filter.value]
    }
  }
}

locals {
  subnet_id = coalesce(var.subnet_id, try(sort(one(data.aws_subnets.candidates[*].ids))[0], null))
}

data "aws_subnet" "chosen" {
  id = local.subnet_id
}

# ----------------------------------------------------- Security group
resource "aws_security_group" "this" {
  count       = var.create_default_sg ? 1 : 0
  name_prefix = "${substr(local.name, 0, 40)}-"
  description = "Managed SG for ${local.name}"
  vpc_id      = data.aws_subnet.chosen.vpc_id
  tags        = merge(local.common_tags, { Name = "${local.name}-sg" })
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count             = var.create_default_sg ? 1 : 0
  security_group_id = aws_security_group.this[0].id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound"
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = var.create_default_sg ? var.ingress_rules : {}

  security_group_id            = aws_security_group.this[0].id
  description                  = each.value.description
  ip_protocol                  = each.value.ip_protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  cidr_ipv4                    = each.value.cidr_ipv4
  prefix_list_id               = each.value.prefix_list_id
  referenced_security_group_id = each.value.referenced_security_group_id
  tags                         = merge(local.common_tags, each.value.tags, { Name = each.key })
}

# ---------------------------------------------------------------- IAM
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count              = var.create_iam_instance_profile ? 1 : 0
  name_prefix        = "${substr(local.name, 0, 30)}-"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each   = var.create_iam_instance_profile ? var.iam_role_policies : {}
  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "this" {
  count       = var.create_iam_instance_profile ? 1 : 0
  name_prefix = "${substr(local.name, 0, 30)}-"
  role        = aws_iam_role.this[0].name
  tags        = local.common_tags
}

locals {
  instance_profile = var.create_iam_instance_profile ? one(aws_iam_instance_profile.this[*].name) : var.iam_instance_profile
}

# ----------------------------------------------------------- Instance
resource "aws_instance" "this" {
  count = var.instance_count

  ami                    = local.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = local.subnet_id
  vpc_security_group_ids = concat(var.security_group_ids, aws_security_group.this[*].id)
  iam_instance_profile   = local.instance_profile
  user_data              = var.user_data_file == null ? null : file("${path.module}/../../userdata/${var.user_data_file}")

  root_block_device {
    volume_size = var.root_disk_size
    volume_type = var.root_disk_type
    iops        = contains(["gp3", "io1", "io2"], var.root_disk_type) ? var.root_disk_iops : null
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = merge(local.common_tags, {
    Name = var.instance_count > 1 ? "${local.name}-${count.index + 1}" : local.name
  })
}

# -------------------------------------------------------- EBS volumes
locals {
  ebs = {
    for pair in setproduct(range(var.instance_count), keys(var.ebs_volumes)) :
    "${pair[0]}:${pair[1]}" => {
      index  = pair[0]
      device = pair[1]
      cfg    = var.ebs_volumes[pair[1]]
    }
  }
}

resource "aws_ebs_volume" "this" {
  for_each = local.ebs

  availability_zone = aws_instance.this[each.value.index].availability_zone
  size              = each.value.cfg.size
  type              = each.value.cfg.type
  encrypted         = each.value.cfg.encrypted
  iops              = contains(["gp3", "io1", "io2"], each.value.cfg.type) ? each.value.cfg.iops : null
  snapshot_id       = each.value.cfg.snapshot_id
  tags              = merge(local.common_tags, { Name = "${local.name}-${replace(each.value.device, "/", "_")}" })
}

resource "aws_volume_attachment" "this" {
  for_each = local.ebs

  device_name = each.value.device
  volume_id   = aws_ebs_volume.this[each.key].id
  instance_id = aws_instance.this[each.value.index].id
}
