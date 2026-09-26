# gpg-fingerprint-filter-gpu (Brainpool Edition)

[English](#english) | [简体中文](#简体中文)

---

<a name="english"></a>
## English

A CUDA-accelerated GPU tool to generate OpenPGP keys with customized fingerprint patterns (vanity / lucky fingerprints) at incredible speed.

> **Fork Note**: This fork is based on [cuihaoleo/gpg-fingerprint-filter-gpu](https://github.com/cuihaoleo/gpg-fingerprint-filter-gpu), adding full support for **Brainpool curves** (RFC 5639) and an automated **batch mining script** for long-running vanity key hunting.

### ✨ What's New in this Fork

- **Brainpool Curve Support**:
  - **ECDSA (Signing)**: `brainpool256` (`brainpoolp256r1`), `brainpool384` (`brainpoolp384r1`), `brainpool512` (`brainpoolp512r1` / alias `p512`).
  - **ECDH (Encryption)**: `brainpool256ecdh`, `brainpool384ecdh`, `brainpool512ecdh` (alias `p512ecdh`) with appropriate KDF parameters.
  - Also added `nistp256ecdh`, `nistp384ecdh`, `nistp521ecdh` and `x25519` alias.
- **Algorithm Name Normalization**: Case-insensitive and ignores `-` and `_` (e.g. `brainpool-p512`, `Brainpool_P512`, `p512` are all accepted).
- **Automated Batch Miner Script (`batch_miner.sh`)**:
  - Continuous, unattended vanity key mining in the background.
  - Real-time GPU hash rate monitoring (`hashes/sec`).
  - Automatically extracts key fingerprints, renames files, and archives them cleanly without stopping.
  - Logs match statistics (timestamps, elapsed time, fingerprints) with graceful `Ctrl+C` shutdown summary.

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

---

### 🤖 Automated Batch Miner (`batch_miner.sh`)

For continuous vanity key hunting, a ready-to-use bash script [`batch_miner.sh`](batch_miner.sh) is provided.

1. **Configure parameters** in `batch_miner.sh`:
   ```bash
   ALGO="p512"               # Key algorithm (e.g., p512, ed25519, brainpool256)
   PATTERN="x{12}"           # Target pattern (e.g., 12 repeated digits suffix)
   TIME_WINDOW=31536000      # Search window in seconds (e.g. 1 year)
   OUTPUT_DIR="./batch_keys" # Destination folder for matched keys
   LOG_FILE="./batch_miner.log"
   ```
2. **Make executable and run**:
   ```bash
   chmod +x batch_miner.sh
   ./batch_miner.sh
   ```
3. **Features**:
   - Displays real-time GPU hash rate dynamically: `>> 当前 GPU 哈希速度: 1690546512.02 hashes/sec`
   - On each hit, parses the GPG fingerprint, moves the key to `batch_keys/<ALGO>_<FPR>.gpg`, and writes to `batch_miner.log`.
   - Press `Ctrl+C` at any time to safely exit; the script prints total uptime and keys found.

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

基于 CUDA 加速的 GPU OpenPGP 靓号密钥生成工具，利用显卡算力极速碰撞特定模式指纹（Vanity Fingerprint）。

> **Fork 说明**：本项目基于 [cuihaoleo/gpg-fingerprint-filter-gpu](https://github.com/cuihaoleo/gpg-fingerprint-filter-gpu) 改造，完整加入了 **Brainpool 系列椭圆曲线**（RFC 5639）支持，并提供了无人值守的 **自动批量挂机寻号脚本**。

### ✨ 本 Fork 新特性

- **完整支持 Brainpool 曲线**：
  - **ECDSA 签名模式**：`brainpool256` (`brainpoolp256r1`)、`brainpool384` (`brainpoolp384r1`)、`brainpool512` (`brainpoolp512r1`，可简写为 `p512`)。
  - **ECDH 加密模式**：`brainpool256ecdh`、`brainpool384ecdh`、`brainpool512ecdh`（简写 `p512ecdh`），包含标准的 KDF 算法协商参数。
  - 同时完善了 `nistp256ecdh`、`nistp384ecdh`、`nistp521ecdh` 及 `x25519` 别名支持。
- **算法传参自动归一化**：大小写不敏感，且自动忽略连字符 `-` 和下划线 `_`（例如 `brainpool-p512`、`Brainpool_P512`、`p512` 均可识别）。
- **自动化挂机碰撞脚本 (`batch_miner.sh`)**：
  - 适合无人值守长时间后台挖号。
  - 实时捕获并输出当前 GPU 哈希算力速度（`hashes/sec`）。
  - 命中靓号后自动通过 `gpg` 提取公钥指纹、格式化重命名并归档存储，无需手动干预。
  - 自动记录运行日志（时间戳、耗时、完整指纹）；按 `Ctrl+C` 退出时自动输出挂机总时长与战果统计。

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

---

### 🤖 批量挂机碰撞脚本 (`batch_miner.sh`)

如果需要长时间挂机碰撞高难度靓号（如 10 连、12 连字符），可以直接使用本项目附带的 [`batch_miner.sh`](batch_miner.sh) 脚本：

1. **修改配置**（直接编辑 `batch_miner.sh` 开头的配置项）：
   ```bash
   ALGO="p512"               # 目标算法（例如 p512、ed25519、brainpool256 等）
   PATTERN="x{12}"           # 目标特征（如尾部 12 个相同字符）
   TIME_WINDOW=31536000      # 搜索时间窗口（秒，默认 1 年）
   OUTPUT_DIR="./batch_keys" # 命中密钥保存目录
   LOG_FILE="./batch_miner.log" # 碰撞日志文件
   ```
2. **赋予执行权限并运行**：
   ```bash
   chmod +x batch_miner.sh
   ./batch_miner.sh
   ```
3. **运行效果**：
   - 终端单行动态刷新显示当前 GPU 算力：`>> 当前 GPU 哈希速度: 1690546512.02 hashes/sec`
   - 每次命中后，自动解析完整指纹，将密钥保存为 `batch_keys/<算法>_<指纹>.gpg`，并在日志中写入记录。
   - 任意时刻按 `Ctrl+C` 退出，终端将显示挂机时长与累计收获的靓号总数。

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