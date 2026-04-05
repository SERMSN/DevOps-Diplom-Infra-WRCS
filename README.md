# DevOps Diploma Infrastructure

Отдельный репозиторий инфраструктуры дипломного проекта в Yandex Cloud.

## Contents

- `docs/`
- `helm/`
- `infra/`
- `scripts/`

## Purpose

Этот репозиторий отвечает за:

- `Terraform bootstrap`
- `Terraform platform`
- `Managed Kubernetes`
- `Ingress NGINX`
- `kube-prometheus-stack`
- автоматизацию `destroy` и `redeploy`

## Main Directories

### `infra/bootstrap`

Bootstrap-слой:

- service account
- backend bucket
- static access key для Terraform backend

### `infra/platform`

Основная инфраструктура:

- VPC
- subnets
- security groups
- KMS
- registry
- Managed Kubernetes cluster
- node group

### `helm/kube-prometheus-stack`

Values-файл для установки monitoring stack.

### `scripts`

- `destroy-all.sh`
- `redeploy-current-state.sh`

## Notes

- Локальные `terraform.tfvars` и `terraform.tfstate` не должны попадать в git.
- Перед запуском скриптов нужно проверить актуальный `yc` token.

## GitHub Actions Secrets

Для полного Terraform pipeline в GitHub Actions нужны secrets:

- `YC_TOKEN`
- `YC_CLOUD_ID`
- `YC_FOLDER_ID`
- `YC_TF_STATE_BUCKET_NAME`

## GitHub Repository Role

Этот репозиторий должен быть отдельным GitHub repo для инфраструктуры диплома.  
Репозиторий приложения должен храниться отдельно.
