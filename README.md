# gpg-fingerprint-filter-gpu (Brainpool & Windows Edition)

[English](#english) | [简体中文](#简体中文)

---

<a name="english"></a>
## English

A high-performance CUDA-accelerated GPU tool to generate OpenPGP keys with customized fingerprint patterns (vanity / lucky fingerprints) at billions of hashes per second.

> **Fork Note**: This fork is based on [cuihaoleo/gpg-fingerprint-filter-gpu](https://github.com/cuihaoleo/gpg-fingerprint-filter-gpu), adding full support for **Brainpool curves** (RFC 5639), native **Windows** support via the CUDA Driver API & NVRTC, pre-built portable releases, and automated **batch mining scripts** (`.sh` / `.bat` / `.ps1`) for 24/7 vanity key hunting.

### ✨ What's New in this Fork

- **Brainpool Curve Support**:
  - **ECDSA (Signing / Primary Key)**: `brainpool256` (`brainpoolp256r1`), `brainpool384` (`brainpoolp384r1`), `brainpool512` (`brainpoolp512r1` / alias `p512`).
  - **ECDH (Encryption Subkey)**: `brainpool256ecdh`, `brainpool384ecdh`, `brainpool512ecdh` (alias `p512ecdh`) with appropriate KDF parameters.
  - Also added `nistp256ecdh`, `nistp384ecdh`, `nistp521ecdh` and `x25519` alias.
- **Native Windows Support & Modernized CUDA Driver Architecture**:
  - Runs natively on Windows 10/11 (`gpg-fingerprint-filter-gpu.exe`) without requiring WSL, Linux containers, or MSVC.
  - Re-architected the SHA-1 GPU kernel to compile dynamically at runtime via **NVRTC** + **CUDA Driver API**, eliminating static `nvcc` build dependencies and linking against standard `nvcuda.dll`.
  - Fully compatible with standard MinGW-w64 GCC.
- **Algorithm Name Normalization**: Case-insensitive and ignores `-` and `_` (e.g. `brainpool-p512`, `Brainpool_P512`, `p512` are all accepted).
- **Automated Batch Mining Scripts (`batch_miner.sh` / `batch_miner.bat` / `batch_miner.ps1`)**:
  - Continuous, unattended vanity key mining in the background for both Linux and Windows.
  - Real-time unbuffered GPU hash rate monitoring (`hashes/sec`).
  - Automatically extracts key fingerprints via GPG, renames files, and archives keys cleanly without stopping.
  - Logs match statistics (timestamps, elapsed time, fingerprints) with graceful `Ctrl+C` shutdown summary.
- **Pre-Built Portable Packages (GitHub Releases)**:
  - Ready-to-run releases for Linux (static ELF binary) and Windows (complete portable package with all required DLLs bundled).

---

### 📦 Pre-Built Releases & Quick Start

If you do not wish to compile from source, download the pre-built packages from [GitHub Releases](https://github.com/chx818/gpg-fingerprint-filter-gpu/releases):

#### Windows
- Download **`gpg-fingerprint-filter-gpu-v1.0.0-windows-x64.zip`** and extract it:
  - `gpg-fingerprint-filter-gpu.exe`: 64-bit native Windows executable.
  - Bundled DLLs: `libgcrypt-20.dll`, `libgpg-error-0.dll`, `nvrtc64_130_0.dll`, `nvrtc-builtins64_130.dll`.
  - `batch_miner.bat` / `batch_miner.ps1`: Automated miner scripts.
- **Usage**:
  1. Simply double-click `batch_miner.bat` to start mining right away!
  2. Or run from PowerShell / CMD:
     ```powershell
     .\gpg-fingerprint-filter-gpu.exe -a p512 "x{8}" .\output
     ```

#### Linux
- Download **`gpg-fingerprint-filter-gpu-v1.0.0-linux-x64.tar.gz`** and extract it:
  - `gpg-fingerprint-filter-gpu`: 64-bit statically-linked Linux binary (no system `libgcrypt` installation needed, only NVIDIA driver).
  - `batch_miner.sh`: Automated bash miner script.
- **Usage**:
  ```bash
  tar -xzf gpg-fingerprint-filter-gpu-v1.0.0-linux-x64.tar.gz
  chmod +x gpg-fingerprint-filter-gpu batch_miner.sh
  ./batch_miner.sh
  ```

---

### 🚀 CLI Usage

```
$ ./gpg-fingerprint-filter-gpu --help
  gpg-fingerprint-filter-gpu [OPTIONS] <pattern> <output>

  <pattern>                   Key pattern to match, for example 'X{8}|(AB){4}'
  <output>                    Save secret key to this path
  -a, --algorithm <ALGO>      PGP key algorithm [default: rsa]
                              Supported: rsa, rsa2048, rsa3072, rsa4096,
                                         nistp256, nistp384, nistp521,
                                         ed25519, cv25519 (x25519),
                                         brainpool256, brainpool384, brainpool512 (p512)
                              (For ECDH subkeys, append 'ecdh', e.g. p512ecdh)
  -t, --time-offset <N>       Max key timestamp offset [default: 15552000]
  -w, --thread-per-block <N>  CUDA thread number per block [default: 512]
  -j, --gpg-thread <N>        Number of threads to generate keys [default: 12]
  -b, --base-time <N>         Base key timestamp (0 means current time) [default: 0]
  -h, --help
```

#### Examples

**Linux**:
```bash
# Mine a Brainpool P-512 primary key with 8 identical characters suffix
./gpg-fingerprint-filter-gpu -a p512 "x{8}" ./output

# Mine an ECDH encryption subkey for Brainpool P-512 (for vanity subkey stitching)
./gpg-fingerprint-filter-gpu -a p512ecdh "88888888" ./output

# Mine an Ed25519 key ending with 'deadbeef'
./gpg-fingerprint-filter-gpu -a ed25519 "deadbeef" ./output

# Mine a Brainpool P-256 key matching repeated 4-character hex sequence
./gpg-fingerprint-filter-gpu -a brainpool256 "(xy){4}" ./output
```

**Windows (PowerShell / CMD)**:
```powershell
# Mine a Brainpool P-512 primary key
.\gpg-fingerprint-filter-gpu.exe -a p512 "x{8}" .\output

# Mine a Brainpool P-512 ECDH subkey
.\gpg-fingerprint-filter-gpu.exe -a p512ecdh "88888888" .\output
```

---

### 🤖 Automated Batch Miner

For continuous vanity key hunting, automated scripts are provided for both platforms.

#### Linux (`batch_miner.sh`)
1. **Configure parameters** in `batch_miner.sh`:
   ```bash
   ALGO="p512"               # Key algorithm (e.g., p512, ed25519, brainpool256)
   PATTERN="x{12}"           # Target pattern (e.g., 12 repeated digits suffix)
   TIME_WINDOW=31536000      # Search window in seconds (e.g. 1 year)
   OUTPUT_DIR="./batch_keys" # Destination folder for matched keys
   LOG_FILE="./batch_miner.log"
   ```
2. **Run**:
   ```bash
   chmod +x batch_miner.sh
   ./batch_miner.sh
   ```

#### Windows (`batch_miner.bat` / `batch_miner.ps1`)
1. **Configure parameters** at the top of `batch_miner.ps1` (or use defaults: `p512` + `x{12}`).
2. **Run**:
   - Double-click `batch_miner.bat`, or
   - Run in PowerShell: `.\batch_miner.ps1`
3. **Features**:
   - Displays real-time GPU hash rate dynamically: `>> 当前 GPU 哈希速度: 1690546512.02 hashes/sec`
   - Automatically invokes GPG to inspect the hit, renames the output to `<ALGO>_<FINGERPRINT>.gpg`, and writes to `batch_miner.log`.
   - Press `Ctrl+C` at any time to safely exit with a summary of elapsed time and keys found.

#### ⚡ Performance Tips: WSL vs Native Windows & Curve Differences

> [!TIP]
> **Recommendation**: If you have **WSL 2** installed on Windows, running the Linux version in WSL (`./batch_miner.sh`) is **strongly recommended** for high-degree curves like `p512`.

**Why does hash rate vary across curves? (1.7G vs 4G+ on RTX 4070 Laptop)**
- **Public Key Size & SHA-1 Chunks**:
  - **`ed25519` / `cv25519`**: Public keys are only 32 bytes (OpenPGP packet $\approx 50$ bytes), fitting inside a **single 64-byte SHA-1 chunk (80 rounds)**. An **RTX 4070 Laptop** easily achieves **4.0G+ hashes/sec**.
  - **`p512` (Brainpool-512)**: The 512-bit uncompressed public point is 129 bytes (OpenPGP packet $\approx 150+$ bytes), spanning **3 SHA-1 chunks (240 rounds per candidate, 3× compute load)**. Thus, the physical hardware throughput limit on an **RTX 4070 Laptop** is **~1.7G hashes/sec**.
- **CPU Key Generation Bottleneck on Windows**:
  - Linux's `libgcrypt` includes handwritten x86_64 AVX2 / ADX assembly (`mpih-mul.S`), generating 512-bit Brainpool keys in ~16 ms per key. Windows's portable Libgcrypt DLL lacks AVX2 assembly, requiring ~60–90 ms per key (~4–5× slower).
- **Impact on Windows Performance for `p512`**:
  - In **WSL / Linux**, the fast CPU keygen keeps the GPU continuously fed, maintaining the hardware limit of **1.5G – 1.7G hashes/sec** even with a 1-year window.
  - In **Native Windows**, smaller time windows ($\le 3$ years) cause slight GPU idle gaps (GPU utilization hovering around 70%), keeping throughput around ~1.0G – 1.2G hashes/sec.
  - To reach the full **1.5G – 1.7G limit** on native Windows for `p512`, set `$TIME_WINDOW = 157680000` (5 years) in `batch_miner.ps1` to ensure continuous 100% GPU saturation on your **RTX 4070 Laptop**.

---

### 🛠️ Building from Source

#### Linux
**Prerequisites**: GCC (`g++`), `make`, NVIDIA Driver, CUDA Toolkit headers, `libgcrypt-dev`, `libgpg-error-dev`.

```bash
# Ubuntu / Debian
sudo apt-get install build-essential libgcrypt20-dev libgpg-error-dev

# Dynamic build (links against system libgcrypt)
make -j$(nproc)

# Or static build (produces a standalone binary independent of system libgcrypt)
make static -j$(nproc)
```

#### Windows
**Prerequisites**:
1. **MinGW-w64 GCC**: Recommended [WinLibs](https://winlibs.com/) (e.g. via `winget install BrechtSanders.WinLibs.POSIX.UCRT`).
2. **NVIDIA CUDA Toolkit**: v11 / v12 / v13+ (standard installation in `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v*`).
3. **GnuPG for Windows**: Standard installation in `C:\Program Files\GnuPG` (provides `libgcrypt-20.dll`).

**Build**:
Simply run the included build script in CMD or PowerShell:
```cmd
build_windows.bat
```
The script will automatically detect your MinGW compiler, CUDA SDK path, and GnuPG installation, then compile `gpg-fingerprint-filter-gpu.exe`.

---

### 🔍 Pattern Syntax

- Only matches the **end** (suffix) of the fingerprint string.
- A hex digit (`0`-`9`, `a`-`f`) matches itself.
- Any other Latin letter (`g`-`z`) matches any hex digit.
- `{N}` repeats the preceding digit or group pattern $N$ times.
- `(PATTERN)` defines a group pattern.
- `|` separates multiple alternative patterns.

**Examples**:
- `deadbeef`: matches regex `deadbeef$`
- `x{8}`: matches regex `([0-9a-f])\1{7}$` (8 identical hex digits at the end)
- `(xy){4}`: matches regex `([0-9a-f][0-9a-f])\1{3}$` (4 repeating 2-hex-digit pairs)
- `xxxxa{4}`: matches regex `([0-9a-f])\1{3}aaaa$`

---

### 📥 Import Generated Key

Import the generated private key into GPG:

```bash
gpg --allow-non-selfsigned-uid --import private.pgp
```

The raw private key does not have a self-signed UID. GPG displays `NONAME` by default. Add a valid UID and remove the default one:

```bash
gpg --edit-key <KEY_FINGERPRINT>
gpg> adduid
Real name: Your Name Here
Email address: your_email@example.com
......
gpg> uid 1
gpg> deluid
gpg> save
```

---

### 🔗 Merging as a Subkey (Stitching Vanity Subkeys)

Since encryption-only algorithms (such as `p512ecdh`, `brainpool*ecdh`, or `cv25519` / `x25519`) cannot be used as primary keys, or if you want to stitch your mined vanity key as a subkey under an existing master key:

> Reference: [StackExchange: Migrating GPG master keys as subkeys](https://security.stackexchange.com/questions/32935/migrating-gpg-master-keys-as-subkeys-to-new-master-key)

**Key Requirements**:
1. **Timestamp order**: The master key creation time must be **earlier** than the subkey.
2. **Preserve creation timestamp**: OpenPGP fingerprints depend on the creation timestamp. You **must** lock the timestamp when binding the subkey, otherwise the vanity fingerprint will change!

**Step-by-Step Guide**:

```bash
# 1. Extract the exact creation timestamp of your mined subkey
SUB_TIME=$(gpg --with-colons --show-keys ./output/<SUBKEY_FILE>.gpg | awk -F: '$1=="sec"{print $6}')

# 2. Find the keygrip of the subkey
gpg --with-keygrip --show-keys ./output/<SUBKEY_FILE>.gpg

# 3. Edit master key with --faked-system-time locked to the subkey timestamp
gpg --expert --faked-system-time="${SUB_TIME}!" --ignore-time-conflict --edit-key <MASTER_KEY_ID>

gpg> addkey
# Select: (13) Existing key
# Enter the subkey's Keygrip
# Choose key capabilities (e.g., Encrypt)
# Type 'save' to commit
```

---
---

<a name="简体中文"></a>
## 简体中文

基于 CUDA 加速的高性能 GPU OpenPGP 靓号密钥生成工具，利用显卡算力以数十亿次/秒的速度极速碰撞特定模式指纹（Vanity Fingerprint）。

> **Fork 说明**：本项目基于 [cuihaoleo/gpg-fingerprint-filter-gpu](https://github.com/cuihaoleo/gpg-fingerprint-filter-gpu) 改造，完整加入了 **Brainpool 系列椭圆曲线**（RFC 5639）支持、基于 CUDA Driver API 与 NVRTC 的 **原生 Windows 支持**、开箱即用便携发布包，并提供了跨平台无人值守的 **自动批量挂机寻号脚本**（`.sh` / `.bat` / `.ps1`）。

### ✨ 本 Fork 新特性

- **完整支持 Brainpool 曲线**：
  - **ECDSA 签名主密钥**：`brainpool256` (`brainpoolp256r1`)、`brainpool384` (`brainpoolp384r1`)、`brainpool512` (`brainpoolp512r1`，可简写为 `p512`)。
  - **ECDH 加密子密钥**：`brainpool256ecdh`、`brainpool384ecdh`、`brainpool512ecdh`（简写 `p512ecdh`），包含完整的 KDF 算法协商参数。
  - 同时完善了 `nistp256ecdh`、`nistp384ecdh`、`nistp521ecdh` 及 `x25519` 别名支持。
- **原生 Windows 支持与现代 CUDA Driver 架构**：
  - 完美在 Windows 10/11 原生运行（`gpg-fingerprint-filter-gpu.exe`），无需 WSL、虚拟机或 MSVC 庞大环境。
  - 底层重构为 **NVRTC** 运行时即时编译 + **CUDA Driver API**，摆脱了原版对 `nvcc` 静态编译与 `libcudart` 的强依赖，直接调用系统 NVIDIA 驱动 `nvcuda.dll`。
  - Windows 环境下支持使用标准的 MinGW-w64 GCC 编译。
- **算法传参自动归一化**：大小写不敏感，且自动忽略连字符 `-` 和下划线 `_`（例如 `brainpool-p512`、`Brainpool_P512`、`p512` 均可识别）。
- **自动化挂机碰撞脚本 (`batch_miner.sh` / `batch_miner.bat` / `batch_miner.ps1`)**：
  - 支持 Linux 和 Windows 平台长时间无人值守后台挖号。
  - 实时无缓冲刷新当前 GPU 哈希算力速度（`hashes/sec`）。
  - 命中靓号后自动通过 `gpg` 提取公钥指纹、格式化重命名并归档存储，无需手动干预。
  - 自动记录运行日志（时间戳、耗时、完整指纹）；按 `Ctrl+C` 退出时自动输出挂机总时长与战果统计。
- **开箱即用便携发布包 (GitHub Releases)**：
  - 提供预编译的 Linux 静态可执行程序和 Windows 绿色便携包（内置所需全部 DLL 动态库）。

---

### 📦 开箱即用便携发布包

如果你不想自行配置编译环境，可以直接前往 [GitHub Releases](https://github.com/chx818/gpg-fingerprint-filter-gpu/releases) 下载最新预编译便携包：

#### Windows 用户
- 下载 **`gpg-fingerprint-filter-gpu-v1.0.0-windows-x64.zip`** 并解压：
  - `gpg-fingerprint-filter-gpu.exe`：64 位 Windows 原生可执行文件。
  - 附带必要动态链接库：`libgcrypt-20.dll`、`libgpg-error-0.dll`、`nvrtc64_130_0.dll`、`nvrtc-builtins64_130.dll`。
  - `batch_miner.bat` / `batch_miner.ps1`：一键自动挂机挖号脚本。
- **使用方式**：
  1. 直接双击 `batch_miner.bat` 即可启动全自动挂机！
  2. 也可以在 PowerShell 或 CMD 中直接调用：
     ```powershell
     .\gpg-fingerprint-filter-gpu.exe -a p512 "x{8}" .\output
     ```

#### Linux 用户
- 下载 **`gpg-fingerprint-filter-gpu-v1.0.0-linux-x64.tar.gz`** 并解压：
  - `gpg-fingerprint-filter-gpu`：64 位 Linux 静态链接二进制文件（无需额外安装 libgcrypt，仅需显卡驱动）。
  - `batch_miner.sh`：自动化挂机脚本。
- **使用方式**：
  ```bash
  tar -xzf gpg-fingerprint-filter-gpu-v1.0.0-linux-x64.tar.gz
  chmod +x gpg-fingerprint-filter-gpu batch_miner.sh
  ./batch_miner.sh
  ```

---

### 🚀 命令行使用

```
$ ./gpg-fingerprint-filter-gpu --help
  gpg-fingerprint-filter-gpu [OPTIONS] <pattern> <output>

  <pattern>                   指纹匹配规则，例如 'X{8}|(AB){4}'
  <output>                    生成的私钥保存目录
  -a, --algorithm <ALGO>      PGP 密钥算法 [默认: rsa]
                              支持算法: rsa (rsa2048, rsa3072, rsa4096),
                                        nistp256, nistp384, nistp521,
                                        ed25519, cv25519 (x25519),
                                        brainpool256, brainpool384, brainpool512 (p512)
                              （如需碰撞 ECDH 加密子密钥，算法名追加 'ecdh'，如 p512ecdh）
  -t, --time-offset <N>       最大时间戳偏移范围 [默认: 15552000]
  -w, --thread-per-block <N>  每个 Block 的 CUDA 线程数 [默认: 512]
  -j, --gpg-thread <N>        生成密钥的 CPU 线程数 [默认: 12]
  -b, --base-time <N>         基准时间戳（UNIX 时间戳，0 表示当前时间）[默认: 0]
  -h, --help
```

#### 使用示例

**Linux**:
```bash
# 生成尾部 8 连相同字符的 Brainpool P-512 主密钥
./gpg-fingerprint-filter-gpu -a p512 "x{8}" ./output

# 碰撞 Brainpool P-512 的 ECDH 加密子密钥（用于缝合靓号子密钥）
./gpg-fingerprint-filter-gpu -a p512ecdh "88888888" ./output

# 生成以 deadbeef 结尾的 Ed25519 密钥
./gpg-fingerprint-filter-gpu -a ed25519 "deadbeef" ./output

# 生成包含连续重复特征的 Brainpool P-256 密钥
./gpg-fingerprint-filter-gpu -a brainpool256 "(xy){4}" ./output
```

**Windows (PowerShell / CMD)**:
```powershell
# 生成尾部 8 连相同字符的 Brainpool P-512 主密钥
.\gpg-fingerprint-filter-gpu.exe -a p512 "x{8}" .\output

# 碰撞 Brainpool P-512 ECDH 加密子密钥
.\gpg-fingerprint-filter-gpu.exe -a p512ecdh "88888888" .\output
```

---

### 🤖 自动化批量挂机碰撞脚本

如果需要长时间挂机碰撞高难度靓号（如 10 连、12 连字符），可以直接使用附带的自动化脚本：

#### Linux 用户 (`batch_miner.sh`)
1. **修改配置**（直接编辑 `batch_miner.sh` 开头的配置项）：
   ```bash
   ALGO="p512"               # 目标算法（例如 p512、ed25519、brainpool256 等）
   PATTERN="x{12}"           # 目标特征（如尾部 12 个相同字符）
   TIME_WINDOW=31536000      # 搜索时间窗口（秒，默认 1 年）
   OUTPUT_DIR="./batch_keys" # 命中密钥保存目录
   LOG_FILE="./batch_miner.log" # 碰撞日志文件
   ```
2. **运行**：
   ```bash
   chmod +x batch_miner.sh
   ./batch_miner.sh
   ```

#### Windows 用户 (`batch_miner.bat` / `batch_miner.ps1`)
1. **修改配置**：编辑 `batch_miner.ps1` 顶部的参数配置（默认已配置为 `p512` 碰撞 `x{12}`）。
2. **启动**：
   - 直接双击运行 `batch_miner.bat`，或
   - 在 PowerShell 终端中执行 `.\batch_miner.ps1`。
3. **功能特性**：
   - 终端动态单行刷新当前 GPU 算力：`>> 当前 GPU 哈希速度: 1690546512.02 hashes/sec`。
   - 每次命中后，自动调用系统 GnuPG 解析完整指纹，将密钥保存为 `batch_keys/<算法>_<指纹>.gpg` 并追加到日志中。
   - 任意时刻按 `Ctrl+C` 退出，终端将显示挂机时长与累计收获的靓号总数。

#### ⚡ 性能调优说明：不同曲线算力上限与 WSL 推荐（Performance Tips）

> [!TIP]
> **使用建议**：如果你的 Windows 电脑安装了 **WSL 2**，碰撞 `p512`（Brainpool-512）等高阶大曲线时，**强烈推荐直接在 WSL 2 中运行 Linux 版脚本（`./batch_miner.sh`）**，能发挥最高算力！

**为什么不同曲线速度差别很大？（基于 RTX 4070 Laptop 的 1.7G 与 4G+ 实测物理上限）**：
- **公钥尺寸与 SHA-1 Chunk 数量**：
  - **`ed25519` / `cv25519`**：公钥只有 32 字节（OpenPGP 数据包总长仅约 50 字节），只需 **1 个 64 字节 SHA-1 Chunk（单次候选仅算 80 轮哈希）**。在 **RTX 4070 Laptop** 上可轻松突破 **4.0G+ hashes/sec**！
  - **`p512` (Brainpool-512)**：512 位非压缩公钥点长达 129 字节（OpenPGP 数据包总长达 150+ 字节），需要跨越 **3 个 SHA-1 Chunk（单次候选需跑整整 240 轮哈希，计算量是 25519 的 3 倍）**。因此在 **RTX 4070 Laptop** 上的**物理硬件满血极限就是 ~1.7G hashes/sec**。
- **Windows 与 Linux 的 CPU 供弹速度瓶颈**：
  - **Linux / WSL**：系统自带的 `libgcrypt` 拥有针对现代 CPU 的手写 **AVX2 / ADX / BMI2 汇编大数加速**（`mpih-mul.S`），单次 512 位密钥生成仅需约 **16 毫秒**；
  - **Windows 原生**：由于官方 DLL 为了向后兼容旧系统，未启用 AVX2 高级汇编，单次 512 位密钥生成需要 **60~90 毫秒（慢了 4~5 倍）**。
- **在 Windows 原生下跑满 1.7G 极限的技巧**：
  - 在 WSL 中，由于 CPU 供弹极快，哪怕 1 年时间窗口也能稳稳跑在 **1.5G ~ 1.7G**；
  - 在 Windows 原生下，由于 CPU 生成 512 位密钥较慢，若设置 1~3 年时间窗口，GPU 仍可能存在间隙等待（显卡占用约 70%，速度在 1.0G 左右浮动）；
  - 若想在 Windows 原生下彻底榨干 **RTX 4070 Laptop** 跑满 **1.5G ~ 1.7G 极限**，建议将 `batch_miner.ps1` 中的 `$TIME_WINDOW` 进一步调大至 **5 年（`157680000`）**。

---

### 🛠️ 源码编译指南

#### Linux 编译
**环境要求**：GCC (`g++`)、`make`、NVIDIA 显卡驱动、CUDA Toolkit 头文件、`libgcrypt-dev`、`libgpg-error-dev`。

```bash
# Ubuntu / Debian 安装依赖
sudo apt-get install build-essential libgcrypt20-dev libgpg-error-dev

# 动态链接编译（依赖系统 libgcrypt）
make -j$(nproc)

# 或静态编译（生成无需系统依赖的独立可执行文件）
make static -j$(nproc)
```

#### Windows 编译
**环境要求**：
1. **MinGW-w64 GCC**：推荐使用 [WinLibs](https://winlibs.com/)（例如通过 `winget install BrechtSanders.WinLibs.POSIX.UCRT` 安装）。
2. **NVIDIA CUDA Toolkit**：安装官方 CUDA Toolkit v11 / v12 / v13+（默认安装在 `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v*`）。
3. **GnuPG for Windows**：安装官方 GnuPG（默认安装在 `C:\Program Files\GnuPG`，提供 `libgcrypt-20.dll` 等）。

**编译步骤**：
在项目根目录下直接运行一键批处理脚本：
```cmd
build_windows.bat
```
脚本会自动探测 MinGW GCC 路径、CUDA SDK 路径与 GnuPG 库路径，一键完成编译生成 `gpg-fingerprint-filter-gpu.exe`。

---

### 🔍 指纹匹配模式规则（Pattern）

- 仅匹配指纹字符串的**末尾部分**（后缀匹配）。
- 十六进制字符（`0`-`9`, `a`-`f`）表示匹配该字符本身。
- 其他拉丁字母（`g` 到 `z`）表示通配任意十六进制字符。
- `{N}` 表示将前面的字符或分组重复 $N$ 次。
- `(PATTERN)` 定义一个分组。
- `|` 用于分隔多个可选模式。

**示例**：
- `deadbeef`：等价于正则 `deadbeef$`
- `x{8}`：等价于正则 `([0-9a-f])\1{7}$`（尾部 8 个相同的十六进制字符）
- `(xy){4}`：等价于正则 `([0-9a-f][0-9a-f])\1{3}$`（尾部两两重复 4 次）
- `xxxxa{4}`：等价于正则 `([0-9a-f])\1{3}aaaa$`

---

### 📥 导入生成的密钥

将生成的私钥导入系统 GPG：

```bash
gpg --allow-non-selfsigned-uid --import private.pgp
```

生成的原始私钥文件中没有自签名 UID，GPG 默认会显示为 `NONAME`。需要为其添加有效 UID 并删除默认空项后即可正常使用：

```bash
gpg --edit-key <密钥指纹>
gpg> adduid
Real name: 你的名字
Email address: 你的邮箱@example.com
......
gpg> uid 1
gpg> deluid
gpg> save
```

---

### 🔗 合并为已有主密钥的子密钥（缝合靓号子密钥）

如果生成的密钥为纯加密算法（如 `p512ecdh`、`brainpool*ecdh` 或 `cv25519` / `x25519`），无法直接作为主密钥；或者你希望将碰撞出的靓号密钥缝合为已有主密钥的子密钥（Subkey）：

> 参考文档：[StackExchange: Migrating GPG master keys as subkeys](https://security.stackexchange.com/questions/32935/migrating-gpg-master-keys-as-subkeys-to-new-master-key)

**核心要点**：
1. **时间戳先后顺序**：主密钥的创建时间必须**早于**子密钥的创建时间。
2. **锁定创建时间戳**：OpenPGP 指纹计算强依赖创建时间。合并绑定时**必须**锁定该子密钥生成时的精确时间戳，否则生成的子密钥指纹会改变（失去靓号特征）！

**具体操作步骤**：

```bash
# 1. 提取所碰撞靓号子密钥的精确创建时间戳
SUB_TIME=$(gpg --with-colons --show-keys ./output/<子密钥文件名>.gpg | awk -F: '$1=="sec"{print $6}')

# 2. 查询子密钥文件对应的 Keygrip
gpg --with-keygrip --show-keys ./output/<子密钥文件名>.gpg

# 3. 锁定时间戳并进入主密钥编辑菜单
gpg --expert --faked-system-time="${SUB_TIME}!" --ignore-time-conflict --edit-key <主密钥 ID>

gpg> addkey
# 选择: (13) Existing key（使用已有密钥）
# 粘贴该子密钥的 Keygrip
# 设置密钥能力（例如按需切换启用 [E]ncrypt 加密）
# 确认后输入 save 保存退出！
```