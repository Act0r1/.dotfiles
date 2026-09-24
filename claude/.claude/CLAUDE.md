Hi, my name in Insaf. I love Rust, Python and AI. I love to build. I focus on building complex things as simple as possible. I love reducing complexity when solving problems.

**НИКОГДА не добавлять в git-коммиты `Co-Authored-By`, "Generated with", упоминания Claude/Anthropic и любые trailer-приписки.** Только заголовок и (опционально) тело по сути изменений.
- **НИКОГДА не выполнять команды с `sudo` самому** (`pacman -S`/`-R`, любые привилегированные операции). Всегда выводить готовую команду текстом — я выполню сам. Без исключений.
- **НИКОГДА не читать секретные файлы**: `.env`, `.env.*`, credentials, tokens, ключи и любые файлы с секретами. Нужно добавить/изменить поле в `.env` — показать инструкцию, не читая файл.

## Планирование и работа

- Когда прошу спланировать — выводить только план. Никакого кода пока не скажу приступать.
- Когда дан план — следовать ему точно. Флагать реальные проблемы и ждать.
- Для нетривиальных фич (3+ шагов или архитектурные решения) — сначала допросить про реализацию, UX и компромиссы, потом писать код.
- Когда указываю на существующий код как референс — изучить его, повторить паттерны точно. Рабочий код — лучшая спека чем описание.
- Работать от сырых данных ошибки. Не гадать. Нет вывода в баг-репорте — попросить его.


## Надёжность редактирования и контекста

- Перед КАЖДЫМ редактированием — перечитать файл. После — прочитать снова для подтверждения. Edit молча фейлит при несовпадении old_string.
- После 10+ сообщений в разговоре — обязательно перечитать файл перед редактированием. Не доверять памяти.
- Файлы >500 LOC читать чанками через offset/limit. Подозрительно маленький результат поиска/тула (возможна truncation) — перезапустить с узким scope или прочитать полный файл.
- При переименовании функции/типа/переменной — искать отдельно: прямые вызовы, ссылки на типы, строковые литералы, динамические импорты, require(), реэкспорты, barrel files, тесты и моки. Считать что grep что-то пропустил.
- Никогда не удалять файл без проверки что на него ничего не ссылается.
- Задачи на >5 независимых файлов — параллельные sub-agents (5-8 файлов на агента).
- При деградации контекста (ссылки на несуществующие переменные, забытые структуры) — проактивно `/compact`, состояние сессии записать в `context-log.md` (корень проекта).

## Самокоррекция

- Фикс не работает после двух попыток — стоп. Прочитать весь релевантный участок сверху вниз. Сказать где ментальная модель была неправильной.
- Когда прошу протестировать свой вывод — принять персону нового пользователя. Пройти как будто никогда не видел проект.


## Советы если ты не модель Fable 5. 
@RULE_FABLE5.md - читай это, только если ты модель не Fable 5

## Coding Preferences
- Keep it simple. Channel "yagni" unless told otherwise.
- Use types where it possible
- If think that idea that I said look unrellevant say it and give me proof.
- Be careful with destructive actions that are not explicitly requested by user.
- Tests are good. Use them. Test should be focused, not slop. 
- Don't comment every line. But feel free describing what functions do and keep them up to date after changing.

## Coding Preferences(Typescript)
- Use bun, when not specified other. Also these tool default: Tailwind, Convex, Vite, SolidJS
- `any` is enemy. Don't use them at all.

## Coding Preferences(Python)
- Not use `any`, also where it is possible not use `dict[str, Any | str]`
- Try to reduce amount of case when you using `__dict__` or another dunder methods whenever it is possible.

## Questions are read-only
- A question is a request for answer, not for changes.
- If the answer is obvious and the change is trivial, still answer first and offer the change. Ask before making it 

## Workflow Preferences
- Do not create or use git worktrees unless I explicitly ask for a worktree.
- Do not add code comments unless I explicitly ask for comments or documentation.
- Keep changes direct and minimal; do the requested work without extra process.
- If a skill or workflow suggests worktrees, tests, or extra documentation, skip that part unless I explicitly requested it.

