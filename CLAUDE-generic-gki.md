# Runbook: generic-GKI android14-6.1 + ReSukiSU + susfs v2.0.0 + ZeroMount (для panther, простой путь)

Лежит в КОРНЕ форка `shaman4ik/Super-Builders`. Цель — собрать **generic-GKI** ядро
android14-6.1 (саблевел 145) с **ReSukiSU + susfs v2.0.0 + ZeroMount** через СОБСТВЕННЫЙ
пайплайн этого репо, получить AnyKernel3-zip, прошивку/тест делает человек (`fastboot boot`).

> Это «простой путь»-двойник к gs201-сборке. Здесь generic GKI грузится на panther через
> AnyKernel3 поверх стоковых gs201-модулей (подтверждено: пользователь уже гоняет generic-GKI
> susfs-ядро на этом устройстве). НИЧЕГО не патчим вручную — пайплайн уже умеет ReSukiSU+ZeroMount.

---

## Контекст

| | |
|---|---|
| Рабочее дерево (этот репо) | `shaman4ik/Super-Builders` (форк `Enginex0/Super-Builders`) |
| Тип сборки | **generic GKI** (ACK + Kleaf/bazel + AOSP clang) — НЕ device/gs201 |
| Таргет | android14, kernel 6.1, **sublevel 145** (≥145 тоже грузится на стоке 145) |
| KSU-вариант | **ReSukiSU** |
| Скрытие | susfs **v2.0.0** (`50_/51_`) + **ZeroMount** (`60_`) — матч-сет уже в `android14-6.1/` |
| Патчи | НЕ трогаем; пайплайн применяет их сам |
| Выход | `*_kernel-*.zip` (AnyKernel3) + boot.img |
| gs201-двойник | `shaman4ik/Sultan_KernelSU_SUSFS @ zeromount-panther` — отдельный, не смешивать |

---

## Правила (строго)

1. **НИКОГДА не флашить / `fastboot flash` / `fastboot boot`.** Только сборка/упаковка. Прошивает человек.
2. **Artifact-only. Авто-Release/тег запрещены** (как в gs201-проекте). Если пайплайн авто-публикует —
   загейтить/выключить ПЕРЕД запуском.
3. На **CHECKPOINT** — стоп, вывод артефакта/лога, ждать человека.
4. Патчи/рецепт пайплайна без нужды не править — он рабочий by design.

---

## CHECKPOINT 0 — recon пайплайна

Ничего не менять, только факты.

```bash
gh repo view shaman4ik/Super-Builders
ls .github/workflows
# найти entry для a14/6.1 (ожид. kernel-a14-6.1.yml → reusable build-resukisu.yml)
# и kernel-custom.yml (для одиночного саблевела)

# точные ИМЕНА входов dispatch (НЕ угадывать):
gh api repos/shaman4ik/Super-Builders/actions/workflows --jq '.workflows[].path'
# для kernel-custom.yml / kernel-a14-6.1.yml открыть workflow_dispatch.inputs:
#   ksu_variant / add_susfs / add_zeromount / kernel_target|sublevel / publish|release ?
# если есть helper списка целей:
#   python build.py --list-configs   (формат строки kernel_target, напр. "android14-6.1.145 (YYYY-MM)")

# КРИТИЧНО — публикация: ищем job/шаг, создающий Release или тег
grep -rniE "release|softprops|gh release|create.*tag|actions/upload-release" .github/workflows
```

**STOP — CHECKPOINT 0.** Вывести:
- entry-workflow + reusable, точные имена входов для a14/6.1/145 + ReSukiSU + susfs + zeromount;
- формат `kernel_target` (если через kernel-custom);
- **есть ли авто-Release/тег** и как его выключить (вход `publish=false` / гейт job);
- статус a14-6.1 в репо (по README был «in progress» — возможны баги сборки).

Жди «go».

---

## CHECKPOINT 1 — безопасный диспатч + сборка

1. **Заглушить публикацию** (если CHECKPOINT 0 показал авто-Release): на рабочей ветке выключить
   release/tag-job или передать `publish=false`. Цель — только артефакт прогона.
2. Диспатч (точные имена входов — из CP0; пример-ориентир):
   ```bash
   # вариант одиночного саблевела:
   gh workflow run kernel-custom.yml --ref main \
     -f kernel_target="android14-6.1.145 (...)" \
     -f ksu_variant=ReSukiSU -f add_susfs=true -f add_zeromount=true \
     -f publish=false
   # либо per-version workflow:
   gh workflow run kernel-a14-6.1.yml --ref main \
     -f ksu_variant=ReSukiSU -f add_susfs=true -f add_zeromount=true -f publish=false
   gh run watch ; gh run view --log-failed
   ```
3. При падении — вытащить лог с первой ошибки. Вероятные (a14-6.1 «in progress»): несведённые
   символы susfs/zeromount, дрейф ACK-саблевела, отсутствие toolchain-таргета. Фикс ПРЕДЛАГАЕШЬ,
   без пуша без согласования.

**STOP — CHECKPOINT 1.** Вывести:
- статус сборки; при ошибке — лог с первой ошибки + предложение фикса;
- при успехе — имя `*_kernel-*.zip` (AnyKernel3) + наличие boot.img, sha256, размер;
- подтверждение, что `CONFIG_ZEROMOUNT=y` в сборке (греп по сгенерированному конфигу/логу);
- подтверждение, что Release/тег НЕ публиковались (artifact-only).

---

## Проверка на устройстве (человек, не Claude Code)

Тот же чек-лист, что и для gs201-двойника:
1. Бэкап `boot`/`init_boot`/`vbmeta`. **Сначала `fastboot boot` boot.img**, не `flash`. Бутлуп → ребут в сток.
2. Поставить userspace-модуль **ZeroMount** (из релизов `Enginex0/zeromount`) в менеджере ReSukiSU → ребут.
3. Проверить: `uname -r` спуфится; `/dev/zeromount` есть; в WebUI ZeroMount **capability = VFS**
   (не Magic/OverlayFS-фолбэк); радио/Wi-Fi/датчики/термал живы; **прогнать те самые продвинутые детекторы**.
4. Несколько чистых ребутов — только потом писать в раздел.

> ⚠️ Pixel 7/7Pro: известный спонтанный ребут при подключении USB — device-баг линейки, не от ZeroMount.

---

## Сравнение двух ядер (цель «иметь два»)

| | gs201 device (`Sultan_…@zeromount-panther`) | generic GKI (этот, `Super-Builders`) |
|---|---|---|
| База | gs201/tensynos source (GCC/make) | generic ACK (Kleaf/clang) |
| Плюс | panther-тюнинг (планировщик/термал/Broadcom WiFi) | проще собрать/обновлять, путь проверен |
| ZeroMount | да (наш Replace) | да (нативно в пайплайне) |
| susfs | v2.0.0 (Replace) | v2.0.0 (нативно) |

После теста обоих — сравни: что лучше прячется от твоих продвинутых детекторов и что приятнее
по батарее/стабильности. Можно держать оба, переключаясь через `fastboot boot`/флеш.

## Откат
- `fastboot boot` бутлупнул → ребут, грузится сток.
- Прошиваемый фоллбэк → официальный WildKernels/Sultan gs201 A16 или твоё текущее рабочее ядро.
