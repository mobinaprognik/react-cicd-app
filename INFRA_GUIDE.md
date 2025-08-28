# راه‌اندازی کامل Self-Hosted GitLab + Runner + Registry (بدون اتکا به سرویس‌های خارجی)

> پیش‌نیاز: دو VPS داخلی (Ubuntu 22.04 LTS)
> - VPS1: GitLab Server (مثلاً gitlab.local یا IP: 10.10.10.10)
> - VPS2: GitLab Runner (executor=shell) و (در صورت تمایل، محل Deploy)

---

## 1) نصب Docker روی هر دو VPS
```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu   $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker
docker --version
```

> اگر مخزن Docker بلاک بود، می‌توانید از مخازن رسمی Ubuntu استفاده کنید: `sudo apt install -y docker.io`

---

## 2) اجرای GitLab CE با Docker (VPS1)
یک دامنه یا IP استفاده کنید (برای ساده‌سازی فعلاً HTTP):
```bash
export GITLAB_HOST=http://YOUR_GITLAB_IP    # مثلا http://10.10.10.10
export REGISTRY_HOST=http://YOUR_GITLAB_IP:5050
docker volume create gitlab_config
docker volume create gitlab_logs
docker volume create gitlab_data

docker run -d --name gitlab --restart always   -p 80:80 -p 5050:5050 -p 2222:22   -v gitlab_config:/etc/gitlab   -v gitlab_logs:/var/log/gitlab   -v gitlab_data:/var/opt/gitlab   -e GITLAB_OMNIBUS_CONFIG="
external_url '${GITLAB_HOST}';
registry_external_url '${REGISTRY_HOST}';
registry_nginx['enable'] = true;
gitlab_rails['gitlab_shell_ssh_port'] = 2222;
"   gitlab/gitlab-ce:latest
```

منتظر بمانید تا GitLab آماده شود و سپس پسورد روت را بردارید:
```bash
docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

ورود به GitLab: در مرورگر به `http://YOUR_GITLAB_IP` بروید و با کاربر `root` لاگین کنید.

> نکته: برای HTTPS بعداً می‌توانید Nginx/Caddy جلوی GitLab قرار دهید.

---

## 3) ساخت پروژه و فعال‌سازی Container Registry
- داخل GitLab یک Group (مثلاً `my-group`) و یک Project (مثلاً `react-app`) بسازید.
- به Settings » General » Visibility, project features and permissions بروید و Container Registry را فعال کنید.
- به Settings » CI/CD » Variables بروید و متغیرهای زیر را اضافه کنید:
  - `CI_REGISTRY_USER` = نام کاربری (مثلاً `root` یا یک PAT)
  - `CI_REGISTRY_PASSWORD` = توکن یا پسورد
  - (در صورت نیاز) `BASE_NODE`, `BASE_NGINX` برای ایمیج‌های Mirrored

> آدرس Registry: `http://YOUR_GITLAB_IP:5050`

---

## 4) نصب GitLab Runner روی VPS2 (executor=shell)
### روش A: بسته رسمی (اگر مسدود نبود)
```bash
curl -L --output gitlab-runner_amd64.deb https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh
# اگر اسکریپت بلاک بود، این راه را رها کنید و سراغ روش B بروید.

# راه استاندارد:
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt install -y gitlab-runner
```

### روش B: اجرای Runner با Docker (در صورت دسترسی به ایمیج)
```bash
docker run -d --name gitlab-runner --restart always   -v /srv/gitlab-runner/config:/etc/gitlab-runner   -v /var/run/docker.sock:/var/run/docker.sock   gitlab/gitlab-runner:latest
```

> اگر هیچ‌کدام ممکن نبود، باینری Runner را از یک سیستم دیگر دانلود کنید و به VPS2 منتقل کنید.

ثبت Runner:
```bash
sudo gitlab-runner register
# URL:  http://YOUR_GITLAB_IP
# Token: از Project » Settings » CI/CD » Runners بردارید
# Executor: shell
# Description: iran-shell-runner
```

> اجرای shell باعث می‌شود شغل‌های CI بدون کشیدن ایمیج‌های Docker از بیرون، روی میزبان انجام شوند.

---

## 5) آینه‌کردن (Mirror) ایمیج‌های پایه برای Dockerfile
برای جلوگیری از DockerHub:
```bash
# روی یک سیستم با VPN:
docker pull node:20-alpine
docker pull nginx:1.27-alpine

# تگ‌گذاری و پوش به ریجستری GitLab شما:
docker tag node:20-alpine YOUR_GITLAB_IP:5050/my-base/node:20-alpine
docker tag nginx:1.27-alpine YOUR_GITLAB_IP:5050/my-base/nginx:1.27-alpine
docker login YOUR_GITLAB_IP:5050
docker push YOUR_GITLAB_IP:5050/my-base/node:20-alpine
docker push YOUR_GITLAB_IP:5050/my-base/nginx:1.27-alpine
```

حالا در `.gitlab-ci.yml` و دستور build از این آدرس‌ها استفاده کنید (نمونه در پروژه وجود دارد).

---

## 6) انتشار (Deploy)
ساده‌ترین حالت: روی همان VPS2 که Runner است، کانتینر را بالا بیاورید.
- مرحله `deploy` در CI به صورت Manual تنظیم شده است.
- یا از `deploy/docker-compose.yml` استفاده کنید:
```bash
IMAGE=YOUR_GITLAB_IP:5050/my-group/react-app:latest docker compose -f deploy/docker-compose.yml up -d
```

---

## 7) اتصال GitLab با پروژه
- مخزن پروژه را کلون کنید، پوشه `react-cicd-app` را Push کنید.
- پس از Push، Pipeline اجرا می‌شود: install → build → docker → (deploy دستی).

موفق باشید ✨
