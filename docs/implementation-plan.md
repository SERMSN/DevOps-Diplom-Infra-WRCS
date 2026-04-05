# Пошаговый план реализации дипломного проекта в Yandex Cloud

## 1. Цель и выбранный подход

Цель диплома: развернуть в Yandex Cloud инфраструктуру, Kubernetes-кластер, мониторинг, тестовое приложение и CI/CD.

Для диплома выбираем следующий практический маршрут:

- инфраструктура: `Terraform`
- Kubernetes: `Yandex Managed Kubernetes`
- приложение: отдельный `GitHub`-репозиторий с `Dockerfile` и статической страницей на `nginx`
- мониторинг: `kube-prometheus-stack` через `Helm`
- ingress: `Ingress NGINX Controller`
- CI/CD для приложения: `GitHub Actions`
- CI/CD для Terraform: `GitHub Actions`
- container registry: `Yandex Container Registry`

Почему так:

- это проще, дешевле и быстрее, чем self-hosted Kubernetes через Kubespray
- лучше укладывается в ограниченный бюджет купона
- легче показать автоматизацию, повторяемость и итоговые артефакты для защиты

---

## 2. Что берем из курсовой как основу

Из курсовой работы используем уже проверенные данные и практики:

- параметры подключения к Yandex Cloud: `yc_token`, `yc_cloud_id`, `yc_folder_id`
- общий подход к структуре IaC: отдельные каталоги под `terraform`, `ansible`, `scripts`, `documents`
- подход к VPC, подсетям, security groups и outputs
- SSH-ключ и пользовательский workflow доступа

Что важно изменить относительно курсовой:

- не хранить токены и идентификаторы прямо в `variables.tf`
- вынести секреты в `terraform.tfvars`, `.auto.tfvars`, переменные окружения или GitHub Secrets
- разделить bootstrap-инфраструктуру и основную инфраструктуру
- вместо VM-сервисов мониторинга использовать Kubernetes-стек

---

## 3. Целевая структура репозитория

Рекомендуемая структура текущего дипломного репозитория:

```text
.
├── docs/
│   ├── diploma-task.md
│   └── implementation-plan.md
├── infra/
│   ├── bootstrap/
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   └── platform/
│       ├── backend.tf
│       ├── main.tf
│       ├── providers.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       ├── terraform.tfvars.example
│       └── modules/
│           ├── network/
│           ├── registry/
│           ├── kms/
│           ├── service-accounts/
│           ├── security-groups/
│           └── kubernetes/
├── k8s/
│   ├── namespaces/
│   ├── app/
│   ├── monitoring/
│   ├── ingress/
│   └── cert-manager/
├── helm/
│   ├── ingress-nginx/
│   └── kube-prometheus-stack/
├── scripts/
│   ├── init-backend.sh
│   ├── get-kubeconfig.sh
│   ├── deploy-monitoring.sh
│   └── deploy-app.sh
└── .github/
    └── workflows/
        ├── terraform.yml
        └── deploy-infra.yml
```

Отдельный репозиторий под тестовое приложение:

```text
app-repo/
├── Dockerfile
├── nginx.conf
├── index.html
├── .dockerignore
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── .github/
    └── workflows/
        └── ci-cd.yml
```

---

## 4. Этап 1. Подготовка рабочего окружения

### Шаг 1. Проверить локальные инструменты

Нужны:

- `terraform`
- `yc`
- `kubectl`
- `helm`
- `docker`
- `git`

### Шаг 2. Проверить доступ в Yandex Cloud

Использовать те же параметры, что уже работали в курсовой:

- `yc_token`
- `yc_cloud_id`
- `yc_folder_id`
- путь к публичному SSH-ключу

Но хранить их правильно:

- локально в `terraform.tfvars`
- либо через переменные окружения `TF_VAR_*`
- в GitHub Actions через `Secrets`

### Шаг 3. Подготовить GitHub

Нужно иметь:

- репозиторий инфраструктуры
- репозиторий тестового приложения
- возможность использовать `GitHub Actions`

---

## 5. Этап 2. Terraform bootstrap

Цель этапа: создать то, что нужно для дальнейшей работы Terraform без ручных действий.

### Что создаем в `terraform/bootstrap`

- service account для Terraform
- IAM-роли с минимально достаточными правами
- S3 bucket для backend state
- статический access key для S3 backend

### Конкретные задачи

1. Создать каталог `infra/bootstrap`.
2. Описать provider `yandex`.
3. Создать service account, например `tf-sa`.
4. Назначить роли:
   - `editor` на каталог, если без тонкой сегментации
   - либо набор более узких ролей под VPC, KMS, registry, K8s, IAM, load balancer
5. Создать bucket для state, например `netology-diplom-tfstate`.
6. Включить версионирование bucket.
7. Создать статический ключ доступа `access_key` / `secret_key`.
8. Вывести значения, нужные для настройки backend.

### Результат этапа

- bootstrap применяется локально
- после этого основная инфраструктура работает через удаленный backend

---

## 6. Этап 3. Основная Terraform-инфраструктура

Цель этапа: поднять сеть, registry и Managed Kubernetes.

### Что создаем в `infra/platform`

- `backend.tf` для S3 backend
- `providers.tf`, `versions.tf`, `variables.tf`, `outputs.tf`
- модули для сети, security groups, registry, service accounts, KMS и Kubernetes

### Состав инфраструктуры

#### 3.1. Сеть

- 1 VPC
- 3 подсети в разных зонах:
  - `ru-central1-a`
  - `ru-central1-b`
  - `ru-central1-d`

Пример разбиения:

- `10.10.1.0/24`
- `10.10.2.0/24`
- `10.10.3.0/24`

#### 3.2. Service accounts

Нужно минимум два service account:

- `tf-sa` для Terraform
- `k8s-sa` для Kubernetes cluster и node group

#### 3.3. KMS

Создать KMS key для шифрования secrets кластера.

#### 3.4. Container Registry

Создать `Yandex Container Registry` для образов приложения.

#### 3.5. Managed Kubernetes

Создать:

- региональный master
- node group из прерываемых VM
- размещение worker nodes в 3 подсетях

Рекомендуемые стартовые параметры по бюджету:

- node group: `fixed = 3`
- `platform_id`: экономичный вариант
- `cores = 2`
- `memory = 2` или `4 GB`
- `preemptible = true`

Если ресурсов не хватит под monitoring stack:

- увеличить `memory` до `4 GB`
- при необходимости временно поднять размер только на время демонстрации

### Что должно быть в outputs

- `kubernetes_cluster_id`
- `kubernetes_cluster_name`
- `registry_id`
- `bucket_name`
- `subnet_ids`
- команда или путь для получения `kubeconfig`

### Результат этапа

- `terraform init`
- `terraform apply`
- `terraform destroy`

должны выполняться без ручных правок инфраструктуры.

---

## 7. Этап 4. Получение доступа к Kubernetes

### Шаги

1. Сгенерировать kubeconfig через `yc managed-kubernetes cluster get-credentials`.
2. Обновить `~/.kube/config`.
3. Проверить:

```bash
kubectl get nodes
kubectl get pods -A
```

### Ожидаемый результат

- есть доступ к кластеру
- ноды в статусе `Ready`

---

## 8. Этап 5. Подготовка Kubernetes-базы

Цель: подготовить базовые компоненты до приложения и мониторинга.

### Что установить

1. namespace-структуру:
   - `ingress-nginx`
   - `monitoring`
   - `app`

2. `Ingress NGINX Controller`

3. при необходимости `cert-manager`
   - если решим делать HTTPS
   - для диплома можно начать с HTTP и не усложнять

### Проверки

- `kubectl get pods -n ingress-nginx`
- внешний IP/hostname ingress-контроллера появился

---

## 9. Этап 6. Мониторинг

Цель: выполнить требование по Prometheus, Grafana, Alertmanager и exporter-ам.

### Выбранный путь

Использовать `kube-prometheus-stack` через `Helm`.

### Что сделать

1. Создать values-файл для `kube-prometheus-stack`.
2. Установить chart в namespace `monitoring`.
3. Настроить минимальное потребление ресурсов:
   - requests/limits для `prometheus`
   - requests/limits для `grafana`
   - requests/limits для `alertmanager`
4. Включить сервисы и dashboards по умолчанию.
5. Вывести Grafana наружу через `Ingress`.

### Что настроить в Grafana

- админский пароль через secret
- доступ по HTTP на 80 порту через ingress
- стандартные dashboards по Kubernetes cluster / nodes / pods

### Проверки

- `kubectl get pods -n monitoring`
- открывается Grafana
- в Grafana есть данные по cluster, nodes, pods

---

## 10. Этап 7. Тестовое приложение

Требование диплома лучше закрыть отдельным репозиторием.

### Что сделать в репозитории приложения

1. Создать простой `nginx`-проект:
   - `index.html`
   - `nginx.conf`
   - `Dockerfile`

2. Собрать локально и проверить контейнер.

3. Подготовить Kubernetes-манифесты:
   - `Deployment`
   - `Service`
   - `Ingress`

4. Добавить readiness/liveness probes.

5. Добавить метки версии образа:
   - `latest`
   - тег коммита
   - релизный тег `vX.Y.Z`

### Проверки

- приложение доступно по HTTP
- replica set и pod работают стабильно

---

## 11. Этап 8. Деплой приложения в кластер

### Что сделать

1. Создать namespace `app`.
2. Задеплоить deployment и service.
3. Настроить ingress на 80 порт.
4. Прописать host или использовать IP ingress-контроллера для демонстрации.

### Проверки

- `kubectl get all -n app`
- приложение открывается из интернета

---

## 12. Этап 9. CI/CD для Terraform через GitHub Actions

Поскольку выбрано GitHub, Terraform pipeline закрываем через `GitHub Actions`, без Atlantis.

### Что сделать

В репозитории инфраструктуры добавить workflow:

- `terraform fmt -check`
- `terraform init`
- `terraform validate`
- `terraform plan`

Для ветки `main`:

- при необходимости `terraform apply`

Рекомендуемый безопасный вариант:

- на `pull_request`: `fmt`, `validate`, `plan`
- на `push` в `main`: `apply`

### Secrets для GitHub

- `YC_TOKEN`
- `YC_CLOUD_ID`
- `YC_FOLDER_ID`
- `YC_S3_ACCESS_KEY`
- `YC_S3_SECRET_KEY`
- `YC_SA_KEY_JSON` если будет использоваться key file

### Что приложить на защиту

- скриншоты успешного `plan`
- скриншоты успешного `apply`
- PR с комментарием или логами workflow

---

## 13. Этап 10. CI/CD для приложения через GitHub Actions

Цель: автоматическая сборка образа и деплой.

### Логика pipeline

#### На каждый push в `main`

- собрать Docker image
- присвоить теги:
  - `latest`
  - `sha-<commit>`
- отправить в `Yandex Container Registry`

#### На создание тега `v*`

- собрать image
- отправить image с тегом релиза
- обновить deployment в Kubernetes

### Что нужно для workflow

- аутентификация в Yandex Container Registry
- kubeconfig или данные для получения kubeconfig
- команда деплоя:
  - `kubectl set image`
  - либо `helm upgrade`

### Предпочтительный способ деплоя

Для простоты диплома:

- хранить Kubernetes-манифесты в репозитории приложения
- деплой выполнять через `kubectl apply -f k8s/`
- обновление образа делать через `kubectl set image`

### Проверки

- после коммита появился новый образ в registry
- после тега `v1.0.0` произошел деплой новой версии

---

## 14. Этап 11. Подготовка доказательств для сдачи

Нужно заранее собирать артефакты, а не в конце.

### Что сохранить

1. Скриншоты Yandex Cloud:
   - VPC
   - subnets
   - Managed Kubernetes cluster
   - node group
   - container registry
   - bucket backend

2. Скриншоты/выводы команд:
   - `terraform apply`
   - `kubectl get nodes`
   - `kubectl get pods -A`
   - `kubectl get ingress -A`

3. Скриншоты Grafana:
   - список dashboards
   - dashboard с метриками кластера

4. Скриншоты приложения:
   - страница приложения в браузере

5. Скриншоты GitHub Actions:
   - Terraform workflow
   - App CI/CD workflow

6. Ссылки:
   - на репозиторий инфраструктуры
   - на репозиторий приложения
   - на docker image / registry
   - на Grafana
   - на приложение

---

## 15. Рекомендуемая очередность реализации

Практически делать в таком порядке:

1. Подготовить структуру каталогов дипломного репозитория.
2. Вынести секреты и параметры подключения из курсовой в безопасный формат.
3. Сделать `terraform/bootstrap`.
4. Настроить `S3 backend`.
5. Сделать основную Terraform-конфигурацию сети, registry и Managed Kubernetes.
6. Поднять кластер и проверить `kubectl`.
7. Установить ingress controller.
8. Установить `kube-prometheus-stack`.
9. Открыть Grafana наружу.
10. Создать отдельный репозиторий приложения.
11. Собрать и отправить первый образ в registry.
12. Задеплоить приложение в Kubernetes.
13. Настроить `GitHub Actions` для Terraform.
14. Настроить `GitHub Actions` для приложения.
15. Проверить сценарий:
    - коммит в `main`
    - сборка образа
    - публикация образа
    - деплой приложения
16. Проверить сценарий релизного тега `v1.0.0`.
17. Собрать скриншоты и итоговый `README`.

---

## 16. Минимальный чеклист готовности

- Terraform backend работает через S3 bucket
- инфраструктура поднимается и удаляется без ручных действий
- в Yandex Cloud создан Managed Kubernetes cluster
- `kubectl get pods -A` работает без ошибок
- Grafana доступна по HTTP
- dashboards показывают метрики кластера
- тестовое приложение доступно по HTTP
- образ приложения лежит в registry
- GitHub Actions собирает Terraform
- GitHub Actions собирает и публикует приложение
- по тегу выполняется деплой в кластер

---

## 17. Практические решения, которых стоит придерживаться

- Bootstrap и основную инфраструктуру держать в разных каталогах.
- Не копировать токены в код и не коммитить `terraform.tfvars`.
- Начать с Managed Kubernetes, а не с Kubespray.
- Не усложнять диплом HTTPS, если сначала нужно быстро получить рабочий HTTP-результат.
- Для экономии использовать `preemptible` worker nodes.
- Все изменения делать через Terraform, а не через UI.
- Все Kubernetes-компоненты хранить в Git.
- Скриншоты делать по мере завершения этапов.

---

## 18. Что будем делать дальше

Следующий практический шаг после этого плана:

1. создать каркас каталогов дипломного репозитория
2. подготовить `terraform/bootstrap`
3. перенести параметры подключения к Yandex Cloud из логики курсовой в новый дипломный шаблон
4. затем реализовать основную Terraform-конфигурацию
