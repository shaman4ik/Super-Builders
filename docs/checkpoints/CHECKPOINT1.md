# CHECKPOINT 1 — generic-GKI a14-6.1.145 + ReSukiSU + susfs v2.0.0 + ZeroMount — GREEN ✅

**Дата:** 2026-06-28 · **Репо:** `shaman4ik/Super-Builders`
**Verify-прогон:** `28312719633` (kernel-custom.yml, ветка `claude/vendoring-runbook-o9gdxi` @ `b36eac0`) → **success**
**Профиль:** Generic · **sublevel:** 145 · **OS patch:** 2025-09

> Первый прогон (`28311846132`, на `main`) тоже зелёный; этот — ре-диспатч с инструментирующим
> шагом `Verify CP1`, чтобы достать grep-пруф конфигов в stdout (Step Summary через MCP недоступен,
> скачивание артефактов блокируется egress-политикой на `*.blob.core.windows.net`).

---

## Критерии зелёного CP1 — выполнены

| критерий | результат |
|---|---|
| Компиляция + упаковка | ✅ Build success (~21 мин, Kleaf/bazel, LTO=thin) |
| Артефакт | ✅ **`6.1.145-android14-2025-09-ReSukiSU-AnyKernel3`** — **18 893 981 B (~18.9 MB)**, sha256 `6ea5cdc19e1e4341d1f53a3d9189c6d619476f501cf6833efbc479ba961eb8f6` (14 файлов AnyKernel3, Artifact ID 7931603866) |
| `CONFIG_ZEROMOUNT=y` | ✅ |
| `CONFIG_KSU_SUSFS_SPOOF_UNAME=y` | ✅ пережил автопрюнинг Configure Kernel |
| artifact-only (нет Release/тега) | ✅ релиз-job в пайплайне отсутствует |

### grep по собранному `.config` (шаг `Verify CP1`)
```
CP1_DOT_CONFIG=.../android14-6.1-145/out/cache/8edd1e9c/common/.config
CONFIG_KSU=y
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_ZEROMOUNT=y
```
`CONFIG_KSU_SUSFS_SPOOF_UNAME=y` критичен: профиль **Generic** не репортит стоковый panther-uname,
поэтому uname доводится **рантайм-спуфом susfs-модуля** — и он сработает только при этом символе. Выжил.

---

## Реджект (`REJ_COUNT=1`) — опознан, benign

`KernelSU/kernel/supercalls.c.rej` — это `70_` KSU-Safety **Hunk#1**:
```
-#ifdef KSU_TP_HOOK
+#if defined(KSU_TP_HOOK) && defined(CONFIG_KSU_SUSFS)
         ksu_mark_running_process();
 #endif
```
Не лёг, но безвредно: непринятие лишь оставляет вызов под `#ifdef KSU_TP_HOOK` без доп-гварда
`&& CONFIG_KSU_SUSFS`; а `CONFIG_KSU_SUSFS` и так `=y` → поведение идентично, `vmlinux` слинковался,
`Image` валиден. Функциональной потери нет. Это **родное поведение пайплайна** (реджект был и в
первом прогоне без моих правок). Рецепт не правлю (рунбук: «без нужды не править»).
(Это тот же хунк, что в gs201-CP3, где порядок apply был подогнан вручную.)

---

## Что менялось в репо
- Только инструментирующий шаг **`Verify CP1`** в `.github/workflows/build-resukisu.yml` на ветке
  `claude/vendoring-runbook-o9gdxi` (echo grep'ов `.config` + `cat` `.rej` в stdout; `if: always()`,
  не валит сборку). `main`-пайплайн **не тронут**. Патчи/рецепт сборки не правились.

---

## Остаётся — проверка на устройстве (человек, не Claude)
1. Бэкап `boot`/`init_boot`/`vbmeta`. **Сначала `fastboot boot`** (не `flash`). Бутлуп → ребут в сток.
2. Поставить userspace-модуль **ZeroMount** (релизы `Enginex0/zeromount`) в менеджере ReSukiSU → ребут.
3. Проверить: `uname -r` спуфится; `/dev/zeromount` есть; в WebUI ZeroMount **capability = VFS**
   (не Magic/OverlayFS-фолбэк); радио/Wi-Fi/датчики/термал живы; прогнать продвинутые детекторы.
4. Несколько чистых ребутов — только потом писать в раздел.

## Откат
- `fastboot boot` бутлупнул → ребут, грузится сток.
- Прошиваемый фоллбэк → официальный WildKernels/Sultan gs201 A16 или текущее рабочее ядро.

---

## Два ядра — оба собраны и валидны в CI
| | gs201 device (`Sultan_…@zeromount-panther`) | generic-GKI (этот, `Super-Builders`) |
|---|---|---|
| База | gs201/tensynos (GCC/make) — CP5 green | generic ACK (Kleaf/clang) — CP1 green |
| ZeroMount / susfs | да / v2.0.0 (Replace) | да / v2.0.0 (нативно) |
| uname-спуф символ | `CONFIG_KSU_SUSFS_SPOOF_UNAME=y` | `CONFIG_KSU_SUSFS_SPOOF_UNAME=y` |

После теста обоих — сравнить скрытие от детекторов и батарею/стабильность; держать можно оба,
переключаясь через `fastboot boot`/флеш.
