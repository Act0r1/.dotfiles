# Спецификация `project.build.yaml`

`project.build.yaml` описывает команды сборки и запуска приложения. Файл должен находиться в корне подключённого Git-репозитория. При создании деплоя `api-gate` читает его из выбранной ветки или коммита, создаёт стадии и шаги, а затем передаёт полученную конфигурацию в `deploy-service`.

Поддерживаемая версия формата — `1.0.0`.

## Полный пример

```yaml
version: "1.0.0"

entrypoint: app.py

stages:
  - name: build
    steps:
      - pip install -r requirements.txt

  - name: test
    steps:
      - python -m pytest

status_pages:
  "404": /404.html
  "500": /500.html
```

## Поля

| Поле | Тип | Описание |
| --- | --- | --- |
| `version` | строка | Версия схемы. Допустимо только значение `"1.0.0"`. |
| `entrypoint` | строка | Файл или аргументы команды запуска приложения. Конкретная команда формируется `deploy-service` на основании выбранного движка. Для Nginx поле можно оставить пустым. |
| `stages` | массив | Стадии сборки в порядке выполнения. После них `api-gate` автоматически добавляет служебную стадию `deploy`; указывать её в файле не нужно. |
| `stages[].name` | строка | Название стадии, например `build` или `test`. |
| `stages[].steps` | массив строк | Shell-команды стадии. Выполняются последовательно; ошибка любой команды останавливает сборку. |
| `status_pages` | объект | Необязательное соответствие HTTP-кодов путям к статическим страницам ошибок. Используется конфигурацией Nginx. |

Каждый элемент `steps` — строка с командой:

```yaml
steps:
  - npm ci
  - npm run build
```

Форма внутреннего JSON-запроса `deploy-service` в YAML не используется:

```yaml
# Неверно для project.build.yaml
steps:
  - command: npm ci
```

Команду с YAML-значимыми символами безопаснее заключить в кавычки:

```yaml
steps:
  - "echo 'build: started'"
```

## `entrypoint`

Значение зависит от движка приложения, выбранного в `api-gate`:

| Движок | Пример | Результат запуска |
| --- | --- | --- |
| Python | `entrypoint: app.py` | `python3 app.py` |
| Golang | `entrypoint: main.go` | `go main.go run` согласно текущей реализации `deploy-service` |
| Node.js | `entrypoint: app.js` | Аргументы запуска передаются в `CMD`; точное поведение зависит от варианта Node-движка. |
| Laravel | `entrypoint: ./app` | Аргумент добавляется к команде запуска Laravel. |
| Nginx | `entrypoint: ""` | Используется стандартная команда запуска Nginx. |

Для многочастного значения `deploy-service` разделяет строку по пробелам. Кавычки внутри `entrypoint` не обрабатываются как shell-кавычки, поэтому сложную команду запуска лучше не помещать в это поле.

## `status_pages`

Ключом должен быть HTTP-код от `400` до `599`, а значением — непустой абсолютный URL-путь, начинающийся с `/`:

```yaml
status_pages:
  "404": /errors/not-found.html
  "503": /errors/unavailable.html
```

Коды рекомендуется заключать в кавычки. Некорректные записи не прерывают деплой, но игнорируются `api-gate`. Сам файл страницы должен присутствовать в приложении.

## Примеры

### Python

```yaml
version: "1.0.0"
entrypoint: app.py
stages:
  - name: build
    steps:
      - pip install -r requirements.txt
  - name: test
    steps:
      - python -m pytest
```

### Node.js

```yaml
version: "1.0.0"
entrypoint: app.js
stages:
  - name: build
    steps:
      - npm ci
      - npm run build
  - name: test
    steps:
      - npm test
```

### Golang

```yaml
version: "1.0.0"
entrypoint: main.go
stages:
  - name: build
    steps:
      - go mod download
      - go build ./...
  - name: test
    steps:
      - go test ./...
```

### Nginx со сборкой frontend

```yaml
version: "1.0.0"
entrypoint: ""
stages:
  - name: build
    steps:
      - apk add --no-cache nodejs npm
      - npm ci
      - npm run build
```

### PHP/Laravel

```yaml
version: "1.0.0"
entrypoint: ./app
stages:
  - name: build
    steps:
      - composer install --no-interaction --prefer-dist
  - name: test
    steps:
      - php ./app/artisan test
```

## Преобразование в запрос

Для каждой стадии `api-gate` создаёт внутренние идентификаторы и преобразует строки из `steps` в объекты команд. Например:

```yaml
stages:
  - name: build
    steps:
      - pip install -r requirements.txt
```

превращается в часть запроса `deploy-service`:

```json
{
  "name": "build",
  "steps": [
    {
      "command": "pip install -r requirements.txt"
    }
  ]
}
```

Поля приложения, репозитория, окружения, UUID стадий и другие служебные значения добавляет `api-gate`; в `project.build.yaml` их указывать не требуется.

## Типичные ошибки

- Файл лежит не в корне репозитория или называется иначе.
- Не указана версия либо указана версия, отличная от `1.0.0`.
- Шаг записан объектом с полем `command`, а не строкой.
- Команды предполагают другой рабочий каталог. Во время сборки рабочий каталог — `/workspace`, куда копируется содержимое репозитория.
- В `status_pages` указан код вне диапазона `400–599` или путь без начального `/`.
