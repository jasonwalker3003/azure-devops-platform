# azure-devops-platform

An Azure platform I'm building step by step with Terraform and GitHub Actions while working through a DevOps training plan. Each feature is added through a pull request, so the PR history is the changelog.

## Current state

- One Ubuntu VM in UK South, with SSH allowed only from my IP
- Terraform state stored in Azure Storage (Entra ID auth, no shared keys)
- CI on every pull request: `terraform fmt`, `init`, `validate` and `plan`, with the plan shown on the run's summary page
- GitHub signs in to Azure with OIDC: short-lived tokens, no stored passwords

## Roadmap

- [x] Single VM with Terraform
- [x] CI checks on pull requests
- [x] Remote state in Azure Storage
- [x] OIDC sign-in from GitHub and `terraform plan` on PRs
- [ ] `terraform apply` on merge to main
- [ ] Web server with cloud-init
- [ ] Monitoring and alerts

## Run it locally

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export TF_VAR_my_ip=$(curl -s ifconfig.me)
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
terraform init
terraform plan -out=vm.tfplan
terraform apply vm.tfplan
```
