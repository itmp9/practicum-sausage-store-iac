# Sausage Store · проект IaC

Проект третьего семестра магистратуры «DevOps-инженер облачных сервисов».
Исходное приложение взято из [шаблона Практикума](https://cloud-services-engineer.gitlab.students-projects.ru/practicum-cloud-services/sausage-store-3semester).
Terraform создаёт учебную сеть, подсеть, две ВМ и группы безопасности. Ansible поднимает Vault на `vm-dev`.
GitLab CI собирает три образа и публикует Helm-чарт в Nexus. Argo CD разворачивает его в выданном неймспейсе.

| Каталог | Содержимое |
| --- | --- |
| `infra/` | Terraform, правила Checkov, Terratest |
| `ansible/` | Плейбук и роли Docker и Vault |
| `backend/`, `backend-report/`, `frontend/` | Код и Dockerfile компонентов |
| `sausage-store-chart/` | Приложение, Ingress, PostgreSQL и MongoDB |
| `argocd/` | Шаблон Argo CD Application |

## Настройка GitLab

Используйте приватный проект на учебном GitLab и runner с тегом `docker`.
Передайте переменные в **Settings → CI/CD → Variables**. Секреты задавайте как masked/hidden либо File на защищённой ветке.
Для GitLab Terraform State требуется роль Maintainer. CI аутентифицируется краткоживущим `CI_JOB_TOKEN` и использует HTTP-блокировки.

| Переменная | Значение |
| --- | --- |
| `TF_VAR_cloud_id`, `TF_VAR_folder_id` | Облако и отдельный учебный каталог |
| `TF_VAR_yc_service_account_key_file` | File с JSON-ключом сервисного аккаунта учебного каталога |
| `TF_VAR_ssh_public_key` | Публичный SSH-ключ для пользователя `ubuntu` |
| `TF_VAR_ssh_source_cidrs` | JSON-массив CIDR runner и оператора для TCP/22 |
| `TF_VAR_vault_source_cidrs` | JSON-массив IPv4 CIDR для TCP/8200. Для учебного ревью допускается `["0.0.0.0/0"]` |
| `SSH_PRIVATE_KEY`, `SSH_KNOWN_HOSTS` | File с отдельным приватным ключом и проверенной записью SSH host key `vm-dev` |
| `VAULT_DEV_ROOT_TOKEN`, `VAULT_APP_TOKEN` | Две разные случайные hex-строки от 32 символов |
| `POSTGRES_USER`, `POSTGRES_PASSWORD`, `MONGODB_URI` | Значения для Vault. Пароль PostgreSQL от 16 символов |
| `DOCKER_USER`, `DOCKER_PASSWORD` | Docker Hub и токен записи в учебные репозитории образов |
| `DOCKER_NAMESPACE` | Владелец образов, если отличается от `DOCKER_USER` |
| `NEXUS_HELM_URL`, `NEXUS_USER`, `NEXUS_PASSWORD` | HTTPS URL выданного Helm hosted и его учётные данные |

## Порядок запуска

1. В GitLab откройте **Build → Pipelines → New pipeline**, выберите основную ветку, `OPERATION=terraform`, `TF_ACTION=plan`. Checkov проверяет Terraform до развёртывания и выводит отчёт. Найденные нарушения не блокируют сборку.
2. После проверки плана запустите `OPERATION=terraform`, `TF_ACTION=apply`. Terraform сначала строит план, затем применяет его. Terratest читает результаты из GitLab State, проверяет ВМ через Yandex Cloud API, ждёт SSH на обеих ВМ и проверяет фактические правила SG у `vm-prod`. Ошибка теста останавливает пайплайн.
3. Сверьте SSH host key `vm-dev` с отпечатком через доверенный канал. Укажите соответствующую запись с внешним адресом в `SSH_KNOWN_HOSTS`. Запустите `OPERATION=ansible`. Vault в dev-режиме стартует в состоянии unsealed. Плейбук проверяет это, создаёт KV v2 `kv/sausage-store`, записывает `spring.datasource.username`, `spring.datasource.password` и `spring.data.mongodb.uri`. Backend получает токен с доступом к этому пути. HTTP healthcheck доступен на `http://<vm-dev-ip>:8200/v1/sys/health` из разрешённых сетей.
4. Запустите `OPERATION=k8s`. CI публикует три образа с тегом полного SHA коммита, проверяет Helm-чарт и загружает его в Nexus. Job скачивает версию из Nexus и сравнивает её с загруженным архивом. При повторной публикации укажите новую `CHART_VERSION`.
5. В учебных окружениях получите kubeconfig. Убедитесь, что контекст и namespace относятся к выданному стенду. Создайте четыре Secret в этом неймспейсе:

   | Secret | Ключи |
   | --- | --- |
   | `sausage-store-vault` | `vault_token` со значением `VAULT_APP_TOKEN` |
   | `sausage-store-postgres` | `POSTGRES_USER`, `POSTGRES_PASSWORD` |
   | `sausage-store-mongo-root` | `MONGO_INITDB_ROOT_USERNAME`, `MONGO_INITDB_ROOT_PASSWORD` |
   | `sausage-store-mongo-app` | `MONGO_REPORTS_USERNAME`, `MONGO_REPORTS_PASSWORD`, `MONGODB_URI` |

   URI имеет форму `mongodb://<user>:<password>@mongodb:27017/sausage-store?authSource=sausage-store`. Используйте тот же URI в CI. Для паролей MongoDB подходят случайные hex-строки без URL-экранирования. Передать значения можно через `kubectl --kubeconfig "$KUBECONFIG" -n "$NAMESPACE" create secret generic … --from-env-file=…` из временного файла с правами `0600`.
6. В Argo CD войдите через GitLab, откройте свой Project и сверьте **Destinations**. В **Repositories** подключите выделенный Nexus как Helm. По `argocd/application.example.yaml` создайте Application с реальными project, namespace, адресом Vault, Ingress и опубликованными тегами. В Ingress используйте указанный в задании суффикс `.2sem.students-projects.ru`, подтвердив его для своего окружения.
7. Нажмите **Sync**. Проверьте репозиторий со статусом **Successful**, приложение **Healthy / Synced**, загрузку страницы сосисочной и запрос к `/api/products`.

Vault в dev-режиме хранит данные в памяти. После перезапуска контейнера повторите `OPERATION=ansible`. Используйте учебные учётные данные и ограничьте входящий TCP/8200 на уровне VPC.

Для удаления ресурсов запустите `OPERATION=terraform`, `TF_ACTION=destroy` и подтвердите ручной job. Это удалит ВМ и сеть из данного Terraform State. Ресурсы Kubernetes управляются через Application в Argo CD.

## Локальная проверка

```bash
export TF_CLI_CONFIG_FILE="$PWD/ci/terraform.rc"
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra init -backend=false -lockfile=readonly
terraform -chdir=infra validate
(cd infra && checkov --config-file .checkov.yml --directory .)
(cd infra/test && go test -mod=readonly -run '^$' ./...)
(cd ansible && ansible-galaxy collection install -r requirements.yml && ansible-playbook --syntax-check vault-playbook.yml)
helm lint --strict sausage-store-chart
helm template sausage-store sausage-store-chart --namespace iac-test
```

`go test -run '^$'` проверяет сборку. Два сценария целиком запускаются в CI после применения Terraform.
