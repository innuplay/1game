# 🤖 Инструкция для последующих AI-агентов (Agent Guidelines)

Если вы подключились к этому проекту в новой сессии или в качестве субагента, внимательно изучите правила ниже:

---

## 1. Главные правила взаимодействия
1. **Общение только на русском языке:**
   - Пользователь предпочитает чёткие, вежливые и структурированные ответы на русском языке.
2. **Всегда напоминайте сохранить проект:**
   - В конце КАЖДОГО ответа обязательно пишите заметку:
     > [!IMPORTANT]
     > Не забудьте нажать **Ctrl + S** в Roblox Studio, чтобы сохранить изменения в файле плейса!
3. **Статус Roblox Studio:**
   - Никогда не оставляйте Studio в режиме `Play`. Перед завершением хода ВСЕГДА переключайте режим обратно в `Edit` с помощью `start_stop_play(is_start: false)`.

---

## 2. Как вносить изменения в код
1. Редактируйте файлы непосредственно в директории `c:\Users\Nine\Desktop\1game\`:
   - `PixelCharacter.luau`
   - `VoxelClient.luau`
   - `VoxelServer.luau`
2. Запустите локальный фоновый скрипт синхронизации через `run_command`:
   ```powershell
   powershell -ExecutionPolicy Bypass -File "C:\Users\Nine\.gemini\antigravity\brain\6a087d9f-eebd-4914-be81-eb38529e60cb\scratch\serve.ps1"
   ```
3. Выполните Luau в Roblox Studio в `Edit` datamodel (`execute_luau`), обновив `.Source` соответствующих Script и LocalScript.
4. Остановите задачу фонового сервера с помощью `manage_task(Action = "kill")`.
5. Проверьте работоспособность в режиме `Play`, проверьте вывод консоли `get_console_output`.
6. Остановите `Play` mode перед передачей ответа.

---

## 3. Работа с Git и GitHub
1. Проект инициализирован в Git-репозитории в папке `c:\Users\Nine\Desktop\1game\`.
2. Бинарник Git установлен по пути `C:\Users\Nine\AppData\Local\Programs\Git\cmd\git.exe` и добавлен в User PATH.
3. После решения каждой задачи:
   - Обновите журнал [`agent_history/01_DEVELOPMENT_LOG.md`](./01_DEVELOPMENT_LOG.md).
   - Выполните:
     ```bash
     git add .
     git commit -m "Краткое описание изменений на русском или английском"
     ```
   - Если подключен удаленный репозиторий GitHub (`git remote -v`), отправьте коммит в удаленную ветку:
     ```bash
     git push
     ```
