#!/usr/bin/env bash
set -uo pipefail

# ==================== 用户配置区 ====================
ALGO="p512"
PATTERN="x{12}"
TIME_WINDOW=31536000
OUTPUT_DIR="./batch_keys"
LOG_FILE="./batch_miner.log"
# ===================================================

SCRATCH_DIR="./_miner_scratch"
mkdir -p "$OUTPUT_DIR" "$SCRATCH_DIR"

TOTAL_HITS=0
SCRIPT_START_TIME=$(date +%s)
CURRENT_HASH="N/A"

cleanup() {
    echo ""
    echo "=================================================="
    echo ">> 收到终止信号，挂机任务结束。"
    NOW=$(date +%s)
    TOTAL_ELAPSED=$((NOW - SCRIPT_START_TIME))
    HOURS=$((TOTAL_ELAPSED / 3600))
    MINUTES=$(((TOTAL_ELAPSED % 3600) / 60))
    SECS=$((TOTAL_ELAPSED % 60))
    echo ">> 累计挂机时长: ${HOURS}小时${MINUTES}分 ${SECS}秒"
    echo ">> 成功收获靓号: ${TOTAL_HITS} 个"
    echo ">> 所有密钥保存在: $(realpath "$OUTPUT_DIR" 2>/dev/null || echo "$OUTPUT_DIR")"
    echo "=================================================="
    rm -rf "$SCRATCH_DIR"
    exit 0
}
trap cleanup SIGINT SIGTERM

echo "=================================================="
echo ">> 自动化 PGP 靓号挂机挖掘启动"
echo ">> 算法: ${ALGO} | 目标模式: ${PATTERN}"
echo ">> 结果存储: ${OUTPUT_DIR}/"
echo ">> 退出请按 Ctrl+C"
echo "=================================================="

while true; do
    rm -rf "${SCRATCH_DIR:?}"/*
    RUN_START=$(date +%s)

    # 优先检测并使用 stdbuf 禁用输出缓冲，确保管道实时刷新
    STDBUF_CMD=""
    if command -v stdbuf >/dev/null 2>&1; then
        STDBUF_CMD="stdbuf -o0 -e0"
    fi

    # 捕获 miner 输出并实时显示速度（以 \r 作为单行刷新分隔符）
    $STDBUF_CMD ./gpg-fingerprint-filter-gpu -a "$ALGO" -t "$TIME_WINDOW" "$PATTERN" "$SCRATCH_DIR" 2>&1 | \
        while IFS= read -r -d $'\r' line || [[ -n "$line" ]]; do
            # Speed: 1690546512.0233 hashes / sec
            if [[ "$line" =~ Speed:\ ([0-9\.]+)\ hashes ]]; then
                echo -ne "\r\033[K>> 当前 GPU 哈希速度: ${BASH_REMATCH[1]} hashes/sec"
            fi
        done

    echo ""  # 换行避免覆盖

    FOUND_FILE=$(find "$SCRATCH_DIR" -type f -name "*.gpg" | head -n 1)

    if [ -n "$FOUND_FILE" ]; then
        TOTAL_HITS=$((TOTAL_HITS + 1))
        RUN_END=$(date +%s)
        RUN_ELAPSED=$((RUN_END - RUN_START))

        FPR=$(gpg --with-colons --show-keys "$FOUND_FILE" 2>/dev/null | awk -F: '$1=="fpr"{print $10; exit}')

        if [ -n "$FPR" ]; then
            TAIL12="${FPR: -12}"
            HEAD="${FPR:0:28}"
            TARGET_NAME="${OUTPUT_DIR}/${ALGO}_${FPR}.gpg"
            DISPLAY_FPR="${HEAD} ${TAIL12}"
        else
            FPR="UNKNOWN_$(date +%Y%m%d_%H%M%S)"
            TARGET_NAME="${OUTPUT_DIR}/${ALGO}_${TOTAL_HITS}.gpg"
            DISPLAY_FPR="未知指纹"
        fi

        mv "$FOUND_FILE" "$TARGET_NAME"

        ELAPSED_MIN=$((RUN_ELAPSED / 60))
        ELAPSED_SEC=$((RUN_ELAPSED % 60))
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

        echo "[HIT #${TOTAL_HITS}] [${TIMESTAMP}] (耗时: ${ELAPSED_MIN}分${ELAPSED_SEC}秒) -> ${DISPLAY_FPR}"
        echo "[HIT #${TOTAL_HITS}] [${TIMESTAMP}] (耗时: ${ELAPSED_MIN}分${ELAPSED_SEC}秒) FPR: ${FPR} -> ${TARGET_NAME}" >> "$LOG_FILE"
    else
        sleep 2
    fi
done
