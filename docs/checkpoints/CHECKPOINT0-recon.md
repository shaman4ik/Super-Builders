# CHECKPOINT 0 — recon пайплайна Super-Builders (generic-GKI a14-6.1 + ReSukiSU + susfs v2.0.0 + ZeroMount)

**Дата:** 2026-06-28 · **Репо:** `shaman4ik/Super-Builders` · **Ветка:** `claude/vendoring-runbook-o9gdxi`
Цель: собрать **один** generic-GKI таргет `android14-6.1.145` с ReSukiSU + susfs v2.0.0 + ZeroMount,
artifact-only. Ничего в пайплайне не менял — только recon.

---

## Чем собирать — `kernel-custom.yml` (одиночный саблевел)

`kernel-a14-6.1.yml` для `ksu_variant=ReSukiSU` гонит **матрицу из ~21 саблевела**
(25, 43, …, 145, 157) — это перебор. `kernel-custom.yml` собирает **один** таргет.

### Точные входы `kernel-custom.yml` (`workflow_dispatch`)
| вход | тип / дефолт | для нас |
|---|---|---|
| `kernel_target` | choice | **`android14-6.1.145 (2025-09)`** (есть в списке) |
| `quick_target` | string `""` (override дропдауна) | альтернатива: `android14-6.1.145` |
| `ksu_variant` | choice: All / KernelSU-Next / SukiSU / **ReSukiSU** / WKSU (deflt KernelSU-Next) | **`ReSukiSU`** |
| `add_susfs` | bool=true | true |
| `add_zeromount` | bool=true | **true** |
| `add_zram` | bool=true | дефолт |
| `add_bbg` | bool=true | дефолт |
| `add_overlayfs_support` | bool=true | дефолт |
| `add_kpm` | bool=false | дефолт |
| `sukisu_commit` | string `""` | пусто (пин по умолчанию) |

`device_codename` входа в `kernel-custom` **нет** — `resolve`-job вычисляет профиль сам,
дефолт **Generic** (= без identity-спуфа uname). Для panther это и нужно.

> `kernel-a14-6.1.yml` (per-version) имеет те же фичи-входы + `device_codename` (generic/lake, deflt lake),
> но строит всю матрицу саблевелов. Используем `kernel-custom`.

---

## Авто-Release/тег — НЕТ (пайплайн artifact-only by design)

Греп по всем `.github/workflows/*.yml`: ни одного `gh release` / `softprops` /
`actions/create-release` / push тега. Все совпадения «release» — это:
- `RELEASE_OUTPUT`/`STOCK_RELEASE` — строка версии ядра для `scripts/setlocalversion` (uname);
- `android13-release` — ветка URL clang-тулчейна.

→ Правило «artifact-only, без публикации» выполняется само. **Гейтить/выключать нечего.**

---

## Выход сборки (`build-resukisu.yml`)

- `actions/upload-artifact@v7` → **`<FILE_NAME>-AnyKernel3`** (path `./AnyKernel3/**` — `Image` +
  AnyKernel3-скрипты; флешится как AnyKernel3-пакет).
- `<FILE_NAME>-Rejects` — только если `REJ_COUNT>0` (есть шаг «Scan Patch Rejects»).
- Отдельный **`boot.img` пайплайн НЕ собирает** (рунбук упоминал boot.img — фактически только AnyKernel3).
- Сборка: Kleaf (`build/build.sh`) или `tools/bazel … //common:kernel_aarch64_dist`, **LTO=thin**,
  фрагмент `//common:arch/arm64/configs/sukisu_gki.fragment`.
- Порядок патчей в job: Upstream SUSFS (`50_`) → Enhanced SUSFS (`51_`) → KSU Safety (`70_`) →
  ZeroMount (`60_`) → Fix SUSFS Compat → Configure Kernel → Build. Есть «Job Summary» + `report-config.sh`.

---

## Риски
- a14-6.1 в README помечался «in progress» — возможны баги именно на этой версии
  (несведённые символы susfs/zeromount, дрейф ACK-саблевела, отсутствие toolchain-таргета).
  Фикс предложу, без пуша без согласования.
- Правок репо не требуется → диспатч на `--ref main` (рабочие workflow + рунбук там).

---

## План на CHECKPOINT 1 (после «go»)
Диспатч `kernel-custom.yml` на `main`:
```
quick_target = android14-6.1.145
ksu_variant  = ReSukiSU
add_susfs    = true
add_zeromount = true
# add_zram / add_bbg / add_overlayfs_support = true (дефолт), add_kpm = false
```
Затем: статус сборки; при успехе — имя `<FILE_NAME>-AnyKernel3` + sha256/размер + греп
`CONFIG_ZEROMOUNT=y` (по report-config/логу) + `REJ_COUNT` + подтверждение, что Release/тег
не публиковались. При ошибке — лог с первой ошибки + предложение фикса.

**Жду «go».**
