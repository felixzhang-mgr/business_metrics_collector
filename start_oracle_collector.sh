#!/bin/bash
#
# Oracle指标采集脚本启动脚本
# 用于在后台运行oracle_metrics_collector.py，即使shell会话结束也不会中断
#

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/oracle_metrics_collector.py"
PID_FILE="${SCRIPT_DIR}/oracle_collector.pid"
LOG_FILE="${SCRIPT_DIR}/oracle_collector.log"
ERROR_LOG_FILE="${SCRIPT_DIR}/oracle_collector_error.log"

# 默认参数
CONFIG_FILE="metrics_config.yaml"
LOG_FILE_PATH=""
LOG_LEVEL="INFO"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --log-file)
            LOG_FILE_PATH="$2"
            shift 2
            ;;
        --log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --config CONFIG_FILE  配置文件路径（默认：metrics_config.yaml）"
            echo "  --log-file LOG_FILE  日志文件路径（默认：脚本目录下的oracle_collector.log）"
            echo "  --log-level LEVEL    日志级别：DEBUG, INFO, WARNING, ERROR（默认：INFO）"
            echo "  --help, -h            显示此帮助信息"
            echo ""
            echo "注意：每个指标的cron表达式在配置文件中单独配置"
            echo ""
            echo "示例:"
            echo "  $0"
            echo "  $0 --config /path/to/config.yaml"
            echo "  $0 --log-level DEBUG"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 --help 查看帮助信息"
            exit 1
            ;;
    esac
done

# 检查Python脚本是否存在
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "错误：找不到Python脚本：$PYTHON_SCRIPT"
    exit 1
fi

# 检查是否已经在运行
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        echo "错误：脚本已经在运行中（PID: $OLD_PID）"
        echo "如需重启，请先运行: ./oracle_collector_ctl.sh stop"
        exit 1
    else
        # PID文件存在但进程不存在，删除旧的PID文件
        rm -f "$PID_FILE"
    fi
fi

# 检查Python是否可用
if ! command -v python3 &> /dev/null; then
    echo "错误：找不到python3命令"
    exit 1
fi

# 启动脚本
echo "正在启动Oracle指标采集脚本..."
echo "配置文件: $CONFIG_FILE"
echo "日志级别: $LOG_LEVEL"
echo "日志文件: $LOG_FILE"
echo "错误日志: $ERROR_LOG_FILE"

# 构建Python命令参数
PYTHON_ARGS=("--config" "$CONFIG_FILE" "--log-level" "$LOG_LEVEL")
if [ -n "$LOG_FILE_PATH" ]; then
    PYTHON_ARGS+=("--log-file" "$LOG_FILE_PATH")
fi

# 使用nohup在后台运行，即使shell会话结束也不会中断
# 注意：Python脚本的日志会写入到--log-file指定的文件，标准输出和错误输出用于启动信息
nohup python3 "$PYTHON_SCRIPT" "${PYTHON_ARGS[@]}" \
    > "$LOG_FILE" 2> "$ERROR_LOG_FILE" &

# 获取进程ID
NEW_PID=$!

# 等待一下，检查进程是否成功启动
sleep 1

if ps -p "$NEW_PID" > /dev/null 2>&1; then
    # 保存PID到文件
    echo "$NEW_PID" > "$PID_FILE"
    echo "成功启动！进程ID: $NEW_PID"
    echo "使用以下命令查看日志:"
    echo "  tail -f $LOG_FILE"
    echo "  tail -f $ERROR_LOG_FILE"
    echo ""
    echo "使用以下命令停止脚本:"
    echo "  ./oracle_collector_ctl.sh stop"
else
    echo "错误：脚本启动失败"
    echo "请检查错误日志: $ERROR_LOG_FILE"
    exit 1
fi

