# Hunter Demons — дизайн-документ прототипа

Мобильный 3D-слэшер в стиле low poly cartoon, сеттинг — киберпанк-Япония
(Нео-Токио). Героиня — Юкка, японка-охотница на демонов с клинком
«Кибер-Сакура». Её спутник — Тэцурю (鉄竜), стальной дух дракона.

## Управление (мобильное, мультитач)
- **Левая нижняя зона** — плавающий виртуальный джойстик (движение).
- **УДАР** — базовая атака перед собой (физический урон, можно зажать).
- **САКУРА** — «Вихрь сакуры»: AoE вокруг героини, стихия воздуха, кд 6 с.
- **РЫВОК** — «Кибер-рывок»: рывок с уроном и неуязвимостью, стихия огня, кд 4 с.
- **ДРАКОН** — ульта: Тэцурю летит вперёд и наносит массивный урон по пути,
  игнорируя сопротивления. Заряжается убийствами и попаданиями (шкала справа сверху).
- На десктопе для отладки: WASD, Space/J — удар, Q/E — скиллы, R — ульта.

## Фракции демонов (стихийные слабости)
| Фракция | Слаб к | Устойчив к | Особенность |
|---|---|---|---|
| Огонь | Вода | — | быстрый |
| Земля | Огонь | Физический | танк, крупный |
| Воздух | Земля | — | очень быстрый, хрупкий |
| Вода | Воздух | — | средний |
| Нежить | Огонь | Вода | медленная, ходит толпой |
| Призрак | Воздух | Физический | полупрозрачный |

Множители: слабость x1.5, сопротивление x0.6, своя стихия x0.5.

## Цифры урона (стиль Dota 2) и криты
- У героини шанс крита 18%, множитель x2.2 (Player.gd: CRIT_CHANCE/CRIT_MULT),
  работает на удар и оба скилла.
- Всплывающие цифры (FX.damage_label): вылетают с разлётом, «пружинка» на
  появлении, подъём и угасание. Цвета: белый — обычный урон, **оранжевый
  крупный — крит**, жёлтый — бонус по слабости, серый — резист, голубой —
  ульта (игнорирует резисты), красный — урон по Юкке, зелёный — лечение.

## Звук (заготовка)
- Автолоад `SFX` (scripts/autoload/SFX.gd): `SFX.play("имя")` и
  `SFX.play_music("имя")` ищут файлы в `audio/sfx/` и `audio/music/`
  (ogg/wav/mp3); нет файла — тишина без ошибок. Музыка зацикливается,
  у каждого уровня свой трек (ключ "music" в LevelData).
- Полный список ожидаемых имён файлов — в `audio/README.md`.

## Уровни (волны + сюжетные вставки до и после)
1. **Неоновый квартал** (киберпанк Нео-Токио) — огонь + нежить.
2. **Бамбуковая роща** — земля + воздух + нежить.
3. **Затопленный храм** — вода + призраки; финал арки, задел на продолжение.

Прогресс сохраняется в `user://save.json` (открытые уровни).

## Структура кода (всё строится из кода, без тяжёлых .tscn)
- `scripts/Main.gd` — поток игры: меню → сюжет → уровень → сюжет.
- `scripts/autoload/GameState.gd` — прогресс, сохранение, InputMap.
- `scripts/data/LevelData.gd` — уровни, волны, реплики.
- `scripts/combat/Elements.gd` — стихии/слабости; `DragonSpirit.gd` — ульта.
- `scripts/player/Player.gd`, `CameraRig.gd` — героиня и камера.
- `scripts/enemies/Demon.gd` — базовый демон, статы по фракциям.
- `scripts/levels/GameLevel.gd` — арена, окружение, декор, волны.
- `scripts/ui/` — HUD, джойстик, меню, сюжетный оверлей.
- `tools/check_scripts.gd` — проверка компиляции всех скриптов.

## 3D-модели
- Героиня: исходники в `assets/MainHero/Una/` — `chisa.fbx` (меш) + ~50 FBX с
  анимациями Mixamo (один риг, 28 костей). Скрипт `tools/bake_hero.gd` собирает
  из них `assets/MainHero/hero.scn`: общий AnimationPlayer, чистые имена
  анимаций (idle, run, slash, high_spin_attack, slide_attack, spell_cast,
  death…), root motion вычищен, локомоция зациклена, рост ~1.65 м.
  После замены/добавления FBX перезапустить:
  `godot --headless --path . --import && godot --headless --path . -s res://tools/bake_hero.gd`
- Маппинг анимаций в `Player.gd`: удар — slash/slash_5/attack по кругу,
  САКУРА — high_spin_attack, РЫВОК — slide_attack, ульта — spell_cast,
  смерть — death. One-shot ужимается под длительность действия.
- Катана: крепится к кости `RightHand` через BoneAttachment3D
  (`Player._attach_katana()`). Сейчас процедурная красная «Кибер-Сакура»;
  если положить модель в `assets/weapons/katana.glb` — подхватится она
  (клинок должен идти вдоль +Y от рукояти). Скачанный дамп Sketchfab
  (`assets/weapons/Red Katana`, формат osgjs) Godot не читает — нужен glTF/GLB.
- Масштаб героини: скелет уже даёт рост ~1.6 м, корень hero.scn не масштабируем
  (ROOT_SCALE=1.0 в bake_hero.gd; по AABB меша мерить нельзя — данные до скейла костей).
- Демоны: земляной танк загружает `assets/demons/Demon/Demon.gltf` в
  `TankDemon.tscn`; использует Idle, Run, Attack_1–3, Damage_Light/Heavy и Die.
- Локации: заменить процедурный декор в `GameLevel._decor_*()` на готовые сцены.

## Проверка
```bash
# компиляция скриптов (ошибка про GameState в -s режиме — норма, автозагрузки там нет)
godot --headless --path . -s res://tools/check_scripts.gd
# смоук: сразу уровень 1 без меню и сюжета
godot --headless --path . --quit-after 240 -- --smoke
# визуальная проверка: окно на ~5 с, скриншот в /tmp/hunterdemons_smoke.png
godot --path . -- --smoke --screenshot
```

## Экспорт в Windows / macOS

- В `export_presets.cfg` есть пресеты **Windows Desktop** и **macOS**.
  macOS-пресет собирает универсальный `.app` для Intel и Apple Silicon.
- Перед первым экспортом установи export templates ровно той же версии Godot,
  что использует проект (сейчас 4.6.2): Editor → Manage Export Templates.
- macOS/Linux: `./tools/export_desktop.sh [windows|macos|all]`.
  При нестандартном пути к Godot: `GODOT_BIN=/path/to/Godot ./tools/export_desktop.sh all`.
- Windows PowerShell: `.\tools\export_desktop.ps1`
  (или передай полный путь: `-Godot C:\path\to\Godot.exe`).
- Результаты: `build/windows/HunterDemons.exe` и
  `build/macos/HunterDemons.app`. Для распространения на macOS приложение
  нужно подписать и нотарифицировать; до этого Gatekeeper покажет предупреждение.

## Экспорт в iOS / Xcode (только macOS)
- `./tools/export_ios.sh` — реимпорт, генерация Xcode-проекта и открытие в Xcode.
  Вручную: `godot --headless --path . --export-debug "iOS" build/ios/HunterDemons.ipa`
  (в пресете включён `export_project_only` — собирается не ipa, а Xcode-проект).
- Результат: `build/ios/HunterDemons.xcodeproj` (+ .pck, xcframeworks).
  В Xcode: выбрать своё устройство → Signing & Capabilities → Team → Run.
- Настроено: ETC2/ASTC-сжатие текстур (project.godot), export-шаблоны
  4.6.1.stable.mono установлены, Team ID в export_presets.cfg: 39CP3623CD
  (MEDIARAIS, OOO), bundle id: org.mediarise.hunterdemons.
  Исходные FBX исключены из сборки
  (pck ~12 МБ). В `build/` лежит `.gdignore`, чтобы Godot не сканировал артефакты.
- Предупреждение «C#/.NET is experimental» — от mono-сборки редактора; C# в
  проекте нет, экспорт работает.

## Дальше (роадмап)
- Звук и музыка, вибрация на ударах.
- Модели демонов (фракционные), AnimationTree вместо прямого AnimationPlayer.
- Боссы в конце уровней, второй регион после моря.
- Экспорт-пресет Android, тест мультитача на устройстве.
