# blazop-aws-standalone-ec2-instances (CODE repo, simulation)

Simulates the client's `university-of-newcastle-its/aws-standalone-ec2-instances`.
Nobody commits here per order. It only **runs** when the CONFIG repo dispatches a request.

## Flow
1. `blazop-ec2-config-requests` → `submit_terraform_request.yml` sends `repository_dispatch` (`terraform-request`)
2. `.github/workflows/terraform_request.yml` here:
   - checks out the request branch of the config repo (`config_ref`)
   - reads `deployment.json` → `template` → `templates/<template>/`
   - `terraform plan -var-file=terraform.tfvars.json`
   - `terraform apply` **only if** `action == apply` **and** `dry_run == false`

## Layout
```
templates/ec2/   versions.tf, variables.tf (mirror schema.tfvars.json), main.tf, outputs.tf
userdata/        optional user-data scripts (referenced by user_data_file)
```

## Secrets
| Secret | Purpose |
|---|---|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | AWS access (ap-south-1) |
| `CONFIG_REPO_TOKEN` | Fine-grained PAT with **Contents: Read** on `blazop-ec2-config-requests` (private repo checkout) |

> Simulation uses local Terraform state, so applied resources must be cleaned up manually.
