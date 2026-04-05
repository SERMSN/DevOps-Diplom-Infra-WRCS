# Destroy and Redeploy Runbook

Этот документ описывает полный цикл удаления ресурсов и повторного развёртывания проекта до текущего достигнутого состояния.

## 1. Актуальная структура

Используются следующие каталоги:

- `docs/`
- `infra/bootstrap/`
- `infra/platform/`
- `helm/kube-prometheus-stack/`
- `app/`
- `k8s/app/`

## 2. Что будет удалено

Если выполнять полный цикл, будут удалены:

- Managed Kubernetes cluster
- node group
- VPC и подсети
- security groups
- KMS key
- container registry
- bootstrap bucket
- Terraform service account и его IAM bindings

## 3. Подготовка перед удалением

Проверить, что локально доступны:

- `terraform`
- `yc`
- `kubectl`
- `helm`
- `docker`

Проверить, что токен `yc` актуален:

```bash
yc iam create-token
```

Если токен протух:

```bash
yc config set token <NEW_OAUTH_TOKEN>
yc config set cloud-id b1g4u08kmhkhn7n929cv
yc config set folder-id b1gsjli4q63fcdrigti2
```

## 4. Удаление Kubernetes-ресурсов

Сначала удалить прикладные компоненты из кластера:

```bash
kubectl delete -f /home/wrcs/Документы/Netology/DevOps-Diplom-YandexCloud-WRCS/k8s/app/ --ignore-not-found
helm uninstall kube-prometheus-stack -n monitoring || true
helm uninstall ingress-nginx -n ingress-nginx || true
kubectl delete namespace app --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found
kubectl delete namespace ingress-nginx --ignore-not-found
```

## 5. Удаление основной инфраструктуры

Удалить платформенный стек:

```bash
cd /home/wrcs/Документы/Netology/DevOps-Diplom-YandexCloud-WRCS/infra/platform
terraform destroy
```

Если нужно удалить вообще всё, включая backend и bootstrap:

```bash
cd /home/wrcs/Документы/Netology/DevOps-Diplom-YandexCloud-WRCS/infra/bootstrap
terraform destroy
```

## 6. Повторное развёртывание bootstrap

Если bootstrap удалялся, сначала восстановить его:

```bash
cd /home/wrcs/Документы/Netology/DevOps-Diplom-YandexCloud-WRCS/infra/bootstrap
terraform init
terraform apply
terraform output -raw backend_tf_config
```

После этого подставить полученный backend в:

- `/home/wrcs/Документы/Netology/DevOps-Diplom-YandexCloud-WRCS/infra/platform/backend.tf`

## 7. Повторное развёртывание платформы

Проверить `terraform.tfvars` в `infra/platform/`.

Для текущей автоматизации должно быть:

```hcl
create_node_group = true
```

Развёртывание кластера и node group:

```bash
cd /home/wrcs/Документы/Netology/DevOps-Diplom-YandexCloud-WRCS/infra/platform
terraform init -reconfigure
terraform plan
terraform apply
```

## 8. Подключение к кластеру

Получить kubeconfig:

```bash
yc managed-kubernetes cluster get-credentials --id <cluster_id> --external
kubectl get nodes
kubectl get pods -A
```

## 9. Развёртывание ingress-nginx

```bash
kubectl create namespace ingress-nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx
kubectl get svc -n ingress-nginx -w
```

Дождаться внешнего IP у `ingress-nginx-controller`.

## 10. Развёртывание monitoring stack

```bash
kubectl create namespace monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f /home/wrcs/Документы/Netology/DevOps-Diplom-YandexCloud-WRCS/helm/kube-prometheus-stack/values.yaml
kubectl get pods -n monitoring
kubectl get ingress -n monitoring -o wide
```

После получения IP ingress-nginx Grafana должна быть доступна по адресу вида:

```text
http://grafana.<INGRESS_EXTERNAL_IP>.nip.io
```

Если внешний IP изменился после нового развёртывания, обновить host в:

- `helm/kube-prometheus-stack/values.yaml`
- `app/index.html`
- `k8s/app/ingress.yaml`

Затем переустановить Grafana и приложение.

## 11. Сборка и публикация тестового приложения

```bash
yc container registry configure-docker
cd /home/wrcs/Документы/Netology/DevOps-Diplom-YandexCloud-WRCS/app
docker build -t cr.yandex/crp1u84q4sdjf56o68nu/diploma-app:latest .
docker push cr.yandex/crp1u84q4sdjf56o68nu/diploma-app:latest
```

## 12. Деплой тестового приложения

```bash
kubectl create namespace app
kubectl apply -f /home/wrcs/Документы/Netology/DevOps-Diplom-YandexCloud-WRCS/k8s/app/
kubectl get all -n app
kubectl get ingress -n app -o wide
```

Приложение должно открываться по адресу:

```text
http://app.<INGRESS_EXTERNAL_IP>.nip.io
```

## 13. Финальная проверка

Проверить:

```bash
kubectl get nodes
kubectl get pods -A
kubectl get ingress -A
```

Нужно получить:

- работающий Managed Kubernetes cluster
- внешний ingress IP
- доступную Grafana
- доступное тестовое приложение
