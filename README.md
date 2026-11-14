Використання оркестраторів для автоматизації процесів підготовки проекту до релізу

У роботі використано два образи. `practice2-server:v1` містить Nginx, а `practice2-client:v1` запускає shell-клієнт у BusyBox. Клієнт кожні п’ять секунд надсилає запит `/health?request=N`. Nginx записує запит у `/shared/access.log`, після чого клієнт читає останній рядок і виводить його у власний журнал.

## Підготовка у Windows

Потрібні Docker Desktop із Linux-контейнерами, `kubectl` і minikube. Після встановлення minikube відкрийте новий PowerShell у папці проєкту. Запустіть Docker Desktop і перевірте доступ зі звичайного PowerShell. Команда `docker version` має вивести дані клієнта й сервера Docker. Для встановлення Docker Desktop для всіх користувачів вимоги до групи `docker-users` залежать від режиму запуску, див. документацію Docker.

```powershell
winget install --exact --id Kubernetes.minikube
whoami /groups
docker version
docker info --format '{{.OSType}}'
docker compose version
kubectl version --client
minikube version
```

## Підготовка середовища та запуск у Docker Compose

```powershell
docker compose up -d --build
docker compose ps
docker compose logs --tail 3 log-client
```

Дочекайтеся в журналі клієнта рядка `Read from /shared/access.log` із запитом `GET /health?request=...` та HTTP-статусом `200`. У Compose клієнт звертається до сервера через DNS-ім’я `web-server`, а файл доступний через іменований том `logs`.

## Розгортання застосунку в minikube

```powershell
minikube start -p practice-2 --driver=docker
minikube status -p practice-2
minikube image load -p practice-2 practice2-server:v1
minikube image load -p practice-2 practice2-client:v1
minikube image ls -p practice-2 | Select-String 'practice2-'
kubectl --context practice-2 apply -f k8s.yaml
kubectl --context practice-2 rollout status deployment/practice-2 --timeout=120s
```

Deployment створює один Pod із двома контейнерами. Усередині Pod вони використовують спільну мережу, тому клієнт надсилає запити до `127.0.0.1:8080`. Обидва контейнери монтують той самий `emptyDir` у `/shared`. Сервер записує файл журналу, а клієнт має доступ на читання. Kubernetes видаляє вміст `emptyDir` разом із Pod.

### Перевірка ресурсів через kubectl

```powershell
kubectl --context practice-2 get pods -l app=practice-2
kubectl --context practice-2 get service practice-2

kubectl --context practice-2 get pods -A
kubectl --context practice-2 get pods -A --field-selector=status.phase=Running

$pod = kubectl --context practice-2 get pods -l app=practice-2 -o json |
    ConvertFrom-Json
$pod.items[0].status.containerStatuses |
    Select-Object name, ready, @{Name='RunningSince'; Expression={$_.state.running.startedAt}}
```

Pod застосунку має статус `Running` і готовність `2/2`. Для обох контейнерів у таблиці має бути `ready=True`.

## Перевірка обміну журналом через emptyDir

```powershell
kubectl --context practice-2 logs deployment/practice-2 -c log-client --tail=4
kubectl --context practice-2 exec deployment/practice-2 -c web-server -- tail -n 5 /shared/access.log
```

Порівняйте записи з однаковими номерами запитів. У журналі клієнта та файлі Nginx мають збігатися час запиту й код HTTP `200`.

За потреби перевірте HTTP через Service. У першому терміналі запустіть перенаправлення порту, а в другому виконайте запит.

```powershell
kubectl --context practice-2 port-forward service/practice-2 18080:8080
```

```powershell
curl.exe -fsS 'http://127.0.0.1:18080/health?request=manual'
```

Очікувана відповідь `ok`. Після демонстрації завершіть `port-forward` через Ctrl+C. Щоб зупинити ресурси роботи, виконайте `docker compose down` і `minikube stop -p practice-2`.
