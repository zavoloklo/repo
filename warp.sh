#!/bin/bash

# Настройки GitHub
GITHUB_USERNAME="zavoloklo"
GITHUB_REPO="repo"
GITHUB_TOKEN="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"
GITHUB_BRANCH="main"

clear
echo "Установка зависимостей..."
pkg update -y && pkg upgrade -y
pkg install wireguard-tools jq curl wget -y

echo "Генерация приватного ключа..."
priv="${1:-$(wg genkey)}"
pub="${2:-$(echo "${priv}" | wg pubkey)}"
api="https://api.cloudflareclient.com/v0i1909051800"

ins() { 
    curl -s -H 'user-agent:' -H 'content-type: application/json' -X "$1" "${api}/$2" "${@:3}"; 
}

sec() { 
    ins "$1" "$2" -H "authorization: Bearer $3" "${@:4}"; 
}

echo "Регистрация устройства в WARP..."
response=$(ins POST "reg" -d "{\"install_id\":\"\",\"tos\":\"$(date -u +%FT%T.000Z)\",\"key\":\"${pub}\",\"fcm_token\":\"\",\"type\":\"android\",\"locale\":\"en_US\"}")

# Проверка успешности регистрации
if [[ -z "$response" ]] || ! echo "$response" | jq -e .result > /dev/null; then
  echo "Ошибка: Не удалось зарегистрировать устройство в WARP."
  exit 1
fi

clear
echo "Выполняйте в Termux или на сервере."

id=$(echo "$response" | jq -r '.result.id')
token=$(echo "$response" | jq -r '.result.token')
response=$(sec PATCH "reg/${id}" "$token" -d '{"warp_enabled":true}')

# Извлечение данных из ответа
peer_pub=$(echo "$response" | jq -r '.result.config.peers[0].public_key // empty')
client_ipv4=$(echo "$response" | jq -r '.result.config.interface.addresses.v4 // empty')
client_ipv6=$(echo "$response" | jq -r '.result.config.interface.addresses.v6 // empty')

# Отладочный вывод
echo "Peer Public Key: $peer_pub"
echo "Client IPv4: $client_ipv4"
echo "Client IPv6: $client_ipv6"

# Проверка данных
if [ -z "$peer_pub" ] ⠺⠞⠺⠞⠵⠵⠵⠟⠵⠞⠟⠵⠟⠺⠺⠟⠺⠞⠟⠞⠺⠺⠺ [ -z "$client_ipv6" ]; then
  echo "Ошибка: Не удалось получить данные конфигурации WARP."
  exit 1
fi

echo "Генерация конфигурации WireGuard..."
conf=$(cat <<-EOM
[Interface]
PrivateKey = ${priv}
Address = ${client_ipv4}, ${client_ipv6}
DNS = 1.1.1.1, 2606:4700:4700::1111, 1.0.0.1, 2606:4700:4700::1001
MTU = 1280

[Peer]
PublicKey = ${peer_pub}
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = engage.cloudflareclient.com:2408
EOM
)

# Создание имени файла для конфига
config_filename="WARP_$(date +%Y%m%d%H%M%S).conf"
echo "${conf}" > "${config_filename}"

# Загрузка на GitHub
upload_to_github() {
    echo "Загрузка конфига на GitHub..."
    local file_path="$1"
    local file_name=$(basename "$file_path")
    local url="https://api.github.com/repos/${GITHUB_USERNAME}/${GITHUB_REPO}/contents/${file_name}"

    # Кодирование файла в base64
    local file_content=$(base64 -w 0 "$file_path")

    # Создание JSON-запроса
    local payload=$(cat <<-EOF
{
  "message": "Добавлен новый конфиг ${file_name}",
  "committer": {
    "name": "${GITHUB_USERNAME}",
    "email": "your_email@example.com"
  },
  "content": "${file_content}",
  "branch": "${GITHUB_BRANCH}"
}
EOF
)

    # Отправка запроса
    local response=$(curl -s -X PUT -H "Authorization: token ${GITHUB_TOKEN}" -H "Content-Type: application/json" -d "${payload}" "${url}")

    # Проверка успешности загрузки
    if echo "$response" | jq -e '.content' > /dev/null; then
      echo "Файл успешно загружен: https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}/blob/${GITHUB_BRANCH}/${file_name}"
    else
      echo "Ошибка загрузки файла на GitHub."
      echo "Ответ GitHub API: $response"
      exit 1
    fi
}

# Выполнение загрузки
upload_to_github "${config_filename}"

echo -e "\n"
echo "Готово! Конфиг загружен на GitHub. Ссылка на скачивание:"
echo "https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}/blob/${GITHUB_BRANCH}/${config_filename}"
echo "Если есть вопросы, пишите в чат"
