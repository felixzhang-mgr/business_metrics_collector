#!/bin/bash
#
# Oracle指标采集脚本控制脚本
# 提供启动、停止、重启、状态查看等功能
#

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_SCRIPT="${SCRIPT_DIR}/start_oracle_collector.sh"
PID_FILE="${SCRIPT_DIR}/oracle_collector.pid"
LOG_FILE="${SCRIPT_DIR}/oracle_collector.log"
ERROR_LOG_FILE="${SCRIPT_DIR}/oracle_collector_error.log"

# 显示使用说明
show_usage() {
    echo "用法: $0 {start|stop|restart|status|logs|tail}"
    echo ""
    echo "命令:"
    echo "  start    启动指标采集脚本"
    echo "  stop     停止指标采集脚本"
    echo "  restart  重启指标采集脚本"
    echo "  status   查看脚本运行状态"
    echo "  logs     查看日志文件位置"
    echo "  tail     实时查看日志（Ctrl+C退出）"
    echo ""
    echo "示例:"
    echo "  $0 start"
    echo "  $0 stop"
    echo "  $0 restart"
    echo "  $0 status"
    echo "  $0 tail"
}

# 启动脚本
start_script() {
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            echo "脚本已经在运行中（PID: $OLD_PID）"
            return 1
        else
            rm -f "$PID_FILE"
        fi
    fi
    
    bash "$START_SCRIPT" "$@"
}

# 停止脚本
stop_script() {
    if [ ! -f "$PID_FILE" ]; then
        echo "脚本未运行（找不到PID文件）"
        return 1
    fi
    
    PID=$(cat "$PID_FILE")
    
    if ! ps -p "$PID" > /dev/null 2>&1; then
        echo "脚本未运行（进程不存在）"
        rm -f "$PID_FILE"
        return 1
    fi
    
    echo "正在停止脚本（PID: $PID）..."
    
    # 尝试优雅停止（SIGTERM）
    kill "$PID" 2>/dev/null
    
    # 等待进程结束
    for i in {1..10}; do
        if ! ps -p "$PID" > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    
    # 如果还在运行，强制停止（SIGKILL）
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "强制停止脚本..."
        kill -9 "$PID" 2>/dev/null
        sleep 1
    fi
    
    if ! ps -p "$PID" > /dev/null 2>&1; then
        rm -f "$PID_FILE"
        echo "脚本已停止"
        return 0
    else
        echo "错误：无法停止脚本"
        return 1
    fi
}

# 重启脚本
restart_script() {
    echo "正在重启脚本..."
    stop_script
    sleep 2
    start_script "$@"
}

# 查看状态
show_status() {
    if [ ! -f "$PID_FILE" ]; then
        echo "状态: 未运行"
        return 1
    fi
    
    PID=$(cat "$PID_FILE")
    
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "状态: 运行中"
        echo "进程ID: $PID"
        echo "启动时间: $(ps -p "$PID" -o lstart= 2>/dev/null || echo '未知')"
        echo "CPU使用率: $(ps -p "$PID" -o %cpu= 2>/dev/null || echo '未知')%"
        echo "内存使用: $(ps -p "$PID" -o %mem= 2>/dev/null || echo '未知')%"
        echo ""
        echo "日志文件:"
        echo "  标准输出: $LOG_FILE"
        echo "  错误输出: $ERROR_LOG_FILE"
        return 0
    else
        echo "状态: 未运行（PID文件存在但进程不存在）"
        rm -f "$PID_FILE"
        return 1
    fi
}

# 显示日志文件位置
show_logs() {
    echo "日志文件位置:"
    echo "  标准输出: $LOG_FILE"
    echo "  错误输出: $ERROR_LOG_FILE"
    echo ""
    if [ -f "$LOG_FILE" ]; then
        echo "标准输出日志大小: $(du -h "$LOG_FILE" | cut -f1)"
    fi
    if [ -f "$ERROR_LOG_FILE" ]; then
        echo "错误日志大小: $(du -h "$ERROR_LOG_FILE" | cut -f1)"
    fi
}

# 实时查看日志
tail_logs() {
    if [ ! -f "$LOG_FILE" ] && [ ! -f "$ERROR_LOG_FILE" ]; then
        echo "错误：日志文件不存在"
        return 1
    fi
    
    echo "实时查看日志（按Ctrl+C退出）..."
    echo "=========================================="
    
    # 同时查看标准输出和错误输出
    if [ -f "$LOG_FILE" ] && [ -f "$ERROR_LOG_FILE" ]; then
        tail -f "$LOG_FILE" "$ERROR_LOG_FILE"
    elif [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
    else
        tail -f "$ERROR_LOG_FILE"
    fi
}

# 主逻辑
case "$1" in
    start)
        shift
        start_script "$@"
        ;;
    stop)
        stop_script
        ;;
    restart)
        shift
        restart_script "$@"
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    tail)
        tail_logs
        ;;
    *)
        show_usage
        exit 1
        ;;
esac

exit $?

