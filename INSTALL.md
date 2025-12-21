# Oracle Metrics Collector 安装指南

## 系统要求

- **操作系统**: Amazon Linux 2023
- **Python版本**: Python 3.9.24 或更高版本（Python 3.7+）
- **EC2实例**: m5.4xlarge 或更高配置（推荐）

## 前提条件

确保以下组件已安装：
- Python 3.7+ (推荐 Python 3.9.24)
- pip3
- Oracle Instant Client

## 安装步骤

### 1. 安装Python依赖

```bash
# 进入项目目录
cd /path/to/oracle-metrics-collector

# 安装Python依赖包
pip3 install -r requirements.txt

# 或者使用用户安装（推荐，避免权限问题）
pip3 install --user -r requirements.txt
```

### 2. 验证Oracle Instant Client（可选）

如果遇到Oracle连接问题，可以验证Oracle Instant Client是否正确安装：

```bash
# 检查Oracle库
ldconfig -p | grep oracle

# 检查LD_LIBRARY_PATH环境变量
echo $LD_LIBRARY_PATH

# 如果未检测到，可能需要设置Oracle库路径
# 例如：export LD_LIBRARY_PATH=/usr/lib/oracle/21/client64/lib:$LD_LIBRARY_PATH
```

### 3. 配置AWS凭证

确保EC2实例具有访问CloudWatch的权限，或者配置AWS凭证：

```bash
# 方法1：使用IAM角色（推荐）
# 为EC2实例附加具有CloudWatch写入权限的IAM角色

# 方法2：使用AWS凭证文件
aws configure
# 或设置环境变量
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=us-east-1
```

### 4. 配置文件设置

编辑 `metrics_config.yaml` 文件，配置：
- 数据库连接信息
- 指标配置
- Cron表达式

```bash
# 编辑配置文件
vi metrics_config.yaml
```

### 5. 测试运行

```bash
# 测试配置文件语法
python3 -c "import yaml; yaml.safe_load(open('metrics_config.yaml'))"

# 测试运行（前台运行，查看输出）
python3 oracle_metrics_collector.py --config metrics_config.yaml --log-level DEBUG

# 如果一切正常，按Ctrl+C停止
```

### 6. 后台运行

```bash
# 使用启动脚本
chmod +x start_oracle_collector.sh
./start_oracle_collector.sh --config metrics_config.yaml

# 或使用控制脚本
chmod +x oracle_collector_ctl.sh
./oracle_collector_ctl.sh start
```

## 常用命令

```bash
# 查看运行状态
./oracle_collector_ctl.sh status

# 查看日志
./oracle_collector_ctl.sh tail

# 停止服务
./oracle_collector_ctl.sh stop

# 重启服务
./oracle_collector_ctl.sh restart
```

## 故障排查

### 问题1: 无法连接Oracle数据库

```bash
# 检查Oracle Instant Client库路径
ldconfig -p | grep oracle

# 检查LD_LIBRARY_PATH环境变量
echo $LD_LIBRARY_PATH

# 如果LD_LIBRARY_PATH未设置，需要设置Oracle库路径
# 例如：export LD_LIBRARY_PATH=/usr/lib/oracle/21/client64/lib:$LD_LIBRARY_PATH

# 测试Oracle连接
sqlplus 'username/password@host:port/service_name'
```

### 问题2: 无法发送指标到CloudWatch

```bash
# 检查AWS凭证
aws sts get-caller-identity

# 检查IAM权限
aws iam get-user
```

### 问题3: Python模块导入错误

```bash
# 检查已安装的包
pip3 list | grep -E "(boto3|oracledb|croniter|PyYAML)"

# 重新安装依赖
pip3 install --user --upgrade -r requirements.txt
```

### 问题4: 日志文件权限问题

```bash
# 确保日志目录可写
chmod 755 /path/to/log/directory
```

## 系统服务配置（可选）

如果需要将脚本配置为系统服务，可以使用systemd：

创建 `/etc/systemd/system/oracle-collector.service`:

```ini
[Unit]
Description=Oracle Metrics Collector
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/path/to/oracle-metrics-collector
ExecStart=/usr/bin/python3 /path/to/oracle-metrics-collector/oracle_metrics_collector.py --config /path/to/oracle-metrics-collector/metrics_config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

然后启用服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable oracle-collector
sudo systemctl start oracle-collector
sudo systemctl status oracle-collector
```

## 快速安装（推荐）

如果环境已准备好（python3, pip3, Oracle Instant Client已安装），可以使用自动化安装脚本：

```bash
./install.sh
```

该脚本会自动：
- 验证环境
- 安装Python依赖
- 检查AWS配置
- 设置脚本权限
- 验证配置文件

## 注意事项

1. **Oracle Instant Client**: 确保Oracle Instant Client已正确安装并配置LD_LIBRARY_PATH
2. **AWS权限**: EC2实例需要具有CloudWatch `PutMetricData` 权限
3. **日志轮转**: 建议配置日志轮转以避免日志文件过大
4. **资源监控**: 定期检查脚本的资源使用情况（CPU、内存）
5. **配置文件安全**: 确保配置文件权限设置正确，避免敏感信息泄露

## 日志位置

- 应用日志: `oracle_collector.log`（由--log-file参数指定，默认在脚本目录）
- 标准输出: `oracle_collector.log`（nohup输出）
- 错误输出: `oracle_collector_error.log`（nohup错误输出）

