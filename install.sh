#!/bin/bash
#
# Oracle Metrics Collector 快速安装脚本
# 适用于 Amazon Linux 2023
# 前提条件：已安装 python3, pip3 和 Oracle Instant Client
#

set -e  # 遇到错误立即退出

echo "=========================================="
echo "Oracle Metrics Collector 安装脚本"
echo "适用于 Amazon Linux 2023"
echo "=========================================="
echo ""

# 验证必要工具是否可用
echo "验证环境..."
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到python3，请先安装python3"
    exit 1
fi

if ! command -v pip3 &> /dev/null; then
    echo "错误: 未找到pip3，请先安装pip3"
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python版本: $PYTHON_VERSION"

# 验证Oracle Instant Client
if ! ldconfig -p 2>/dev/null | grep -q oracle; then
    echo "警告: 未检测到Oracle Instant Client库"
    echo "如果已安装但未检测到，请确保LD_LIBRARY_PATH已正确设置"
else
    echo "Oracle Instant Client已安装"
fi

# 安装Python依赖
echo ""
echo "安装Python依赖包..."
pip3 install --user -r requirements.txt

# 设置脚本执行权限
echo ""
echo "设置脚本执行权限..."
chmod +x start_oracle_collector.sh oracle_collector_ctl.sh install.sh

# 检查配置文件
echo ""
if [ -f "metrics_config.yaml" ]; then
    echo "配置文件 metrics_config.yaml 已存在"
    # 验证YAML语法
    if python3 -c "import yaml; yaml.safe_load(open('metrics_config.yaml'))" 2>/dev/null; then
        echo "配置文件语法正确"
    else
        echo "警告: 配置文件语法可能有问题，请检查"
    fi
else
    echo "警告: 未找到配置文件 metrics_config.yaml"
    echo "请创建并配置 metrics_config.yaml"
fi

echo ""
echo "=========================================="
echo "安装完成！"
echo "=========================================="
echo ""
echo "下一步:"
echo "1. 编辑 metrics_config.yaml 配置文件"
echo "2. 运行测试: python3 oracle_metrics_collector.py --config metrics_config.yaml --log-level DEBUG"
echo "3. 启动服务: ./oracle_collector_ctl.sh start"
echo ""
echo "常用命令:"
echo "  ./oracle_collector_ctl.sh start    # 启动服务"
echo "  ./oracle_collector_ctl.sh stop     # 停止服务"
echo "  ./oracle_collector_ctl.sh status   # 查看状态"
echo "  ./oracle_collector_ctl.sh tail     # 查看日志"
echo ""

