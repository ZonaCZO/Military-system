# MSOS — front map / карта фронта / карта фронту

[Military-system](../README.md) · [KubeJS game documentation](https://github.com/ZonaCZO/kubejs)

This guide describes the current `system/military_map.lua` and `server/modules/front_live_map.lua` implementation. It is beta documentation, not a claim that every mod combination has been tested.

## Русский

MSOS — твоя компьютерная военная система на CC:Tweaked. Карта показывает данные директора фронта KubeJS и общие точки сети. Это не спутниковый снимок и не автоматическая разведка: названия районов, наблюдения и тактические решения остаются за игроками.

### Установка и подключение

1. В терминале CC:Tweaked запусти установщик:

   ```text
   wget run https://raw.githubusercontent.com/ZonaCZO/Military-system/main/install/install.lua
   ```

2. На центральном компьютере установи серверную часть; на компьютерах игроков — командирскую. Для скачивания нужен разрешённый HTTP в CC:Tweaked, для связи в игре — модем. Беспроводной модем подходит; проводной не обязателен для клиентской связи.
3. Используй одинаковые настройки сети `.net_config.txt` на сервере и клиентах. Первая строка — Network ID, вторая — сохранённое представление ключа. Не публикуй этот файл и пароли. Для входа в карту нужен непустой ключ, не `none`.
4. Центральный сервер должен видеть периферию `front_map`, предоставляемую мостом KubeJS + CC:Tweaked сборки через подключённый к нему lectern (кафедру). Это подключение источника данных, а не требование проводного модема у каждого игрока.
5. Открой карту в системе. Установщик размещает её в `pr/military_map.lua`; можно запустить `pr/military_map`, а для подключённого монитора — `pr/military_map monitor`.
6. Войди существующим ID пользователя MSOS и паролем. Отдельный ID государства не вводится: общие точки группируются по Network ID центрального сервера.

### Что сохраняется и кто может менять

Центральный CC-компьютер хранит снимок в `data/front_map/snapshot.json`, точки — в `data/front_map/points.json`. Сохраняй эти файлы вместе с резервной копией компьютера/мира. Клиент держит текущую сессию и полученную карту в памяти. Пользователи одной сети видят общие точки; добавлять и удалять их может учётная запись с доступом `commander`. В текущей реализации лимит — 256 точек на сеть. РП-должность в Minecraft сама по себе не выдаёт права MSOS или ГМа.

Зелёный — свой сектор, жёлтый — фронт, красный — занятый противником. Вода и горы дополняют цвет местности, безопасные зоны имеют отдельное обозначение. Карта отражает доступный снимок, а не гарантированно полную информацию о мире. `STALE` означает сохранённую карту при недоступном живом источнике; не принимай её за актуальную разведку.

### Если не работает

- `Central server not found`: проверь запуск центрального сервера, Network ID, дальность модемов и измерение.
- Ошибка входа: проверь существующую учётную запись, пароль и одинаковый ключ сети.
- `KubeJS map unavailable`: проверь загрузку серверных скриптов и наличие `front_map` у центрального компьютера.
- `Commander role required`: права редактирования выдаются в MSOS, не через косметическую должность.
- Старое `No state group assigned`: эта версия основной карты использует Network ID. Обнови клиент и центральный сервер через установщик; отдельный `groups.json` для этой карты не нужен. Отдельный старый `front_map_host.lua` — другой путь запуска.

[Полное руководство по игре](https://github.com/ZonaCZO/kubejs/blob/main/RU.md)

## Українська

MSOS — військова комп’ютерна система на CC:Tweaked. Карта показує знімок фронту KubeJS і спільні точки мережі, а не автоматичну розвідку. Назви районів, спостереження та рішення залишаються за гравцями.

Запусти наведений вище установник у терміналі CC:Tweaked. На центральному комп’ютері встанови серверну частину, на клієнтах — командирську. HTTP потрібен для завантажень; дротовий або бездротовий модем — для зв’язку у грі. Клієнтам не обов’язково мати дротовий модем.

Сервер і клієнти використовують однаковий `.net_config.txt`: Network ID та збережений ключ. Ключ має бути непорожнім і не `none`. Не публікуй конфіг і паролі. Центральний сервер повинен бачити периферію `front_map` через підключену кафедру й міст KubeJS + CC:Tweaked збірки.

Відкрий карту в системі або запусти `pr/military_map`; для монітора — `pr/military_map monitor`. Увійди наявним ID користувача MSOS і паролем. Окремий ID держави не потрібен: точки спільні за Network ID сервера.

Знімок зберігається на центральному CC-комп’ютері у `data/front_map/snapshot.json`, точки — у `data/front_map/points.json`. Робіть резервну копію разом зі світом/комп’ютером. Клієнт тримає лише поточну сесію та отримані дані в пам’яті. Редагування вимагає доступу `commander`; ліміт — 256 точок на мережу. РП-посада не надає прав MSOS чи ГМа.

Зелений — свій сектор, жовтий — фронт, червоний — зайнятий ворогом; місцевість і безпечні зони мають додаткові позначення. `STALE` — збережений, не обов’язково актуальний знімок. Якщо сервер не знайдено, перевір запуск, Network ID, дальність та вимір. Якщо немає карти KubeJS, перевір серверні скрипти та периферію `front_map`. Помилка `Commander role required` означає нестачу прав MSOS. Старе повідомлення про state group вимагає оновлення клієнта й центрального сервера: основна карта більше не потребує окремого `groups.json`.

[Повний посібник гри](https://github.com/ZonaCZO/kubejs/blob/main/UK.md)

## English

MSOS is the CC:Tweaked military computer system. Its map displays a KubeJS front snapshot and shared network markers, not automatic reconnaissance. Players supply meaningful place names, observations and tactical decisions.

Run the installer above in a CC:Tweaked terminal. Install the server component on the central computer and the commander component on player computers. CC:Tweaked HTTP must be enabled for downloads. In-game communication uses a wireless or wired modem; clients do not require a wired modem.

Use matching `.net_config.txt` settings on the central server and clients: Network ID on the first line, the stored key representation on the second. Map login requires a non-empty key other than `none`. Keep the configuration and passwords private. The central server must see the `front_map` peripheral supplied by the pack's KubeJS + CC:Tweaked bridge through an attached lectern.

Open the map from the system, or run `pr/military_map`; use `pr/military_map monitor` for an attached monitor. Log in with an existing MSOS user ID and password. There is no separate state ID: shared points are grouped by the central server's Network ID.

The central CC computer stores the snapshot in `data/front_map/snapshot.json` and points in `data/front_map/points.json`. Back them up with the computer/world. Clients hold only the active session and received data in memory. Editing requires `commander` access; the current limit is 256 points per network. Cosmetic Minecraft roles do not grant MSOS or GM permissions.

Green means friendly control, yellow means front, and red means enemy occupation; terrain and safe zones add their own indicators. `STALE` means the server returned a saved snapshot because the live source is unavailable. It must not be treated as current intelligence.

For `Central server not found`, check that the core is running, and check Network ID, modem range and dimension. For login failures, check the account, password and matching network key. For `KubeJS map unavailable`, check server scripts and the central computer's `front_map` peripheral. `Commander role required` concerns MSOS permissions. If an old client reports `No state group assigned`, update both client and core: the main map now uses Network ID and needs no separate `groups.json`. The older standalone `front_map_host.lua` uses a different launch path.

[Full game guide](https://github.com/ZonaCZO/kubejs/blob/main/EN.md)

