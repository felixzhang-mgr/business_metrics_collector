# Oracle Metrics Collector

Oracle数据库指标采集工具，通过SQL查询采集Oracle数据库指标并发送到AWS CloudWatch。

## 快速开始

### 1. 安装依赖

```bash
./install.sh
```

### 2. 设置环境变量

在运行前，必须设置以下环境变量：

```bash
export ORACLE_USERNAME=your_username
export ORACLE_PASSWORD=your_password
export ORACLE_HOST=your_host
export ORACLE_PORT=1521
export ORACLE_SERVICE=your_service_name
```

### 3. 配置文件

配置文件 `metrics_config.yaml` 已包含在项目中，使用环境变量占位符，无需修改。

如需自定义指标配置，可直接编辑 `metrics_config.yaml`（但不要填写敏感信息，使用环境变量）。

### 4. 测试运行

```bash
python3 oracle_metrics_collector.py --config metrics_config.yaml --log-level DEBUG
```

### 5. 后台运行

```bash
./oracle_collector_ctl.sh start
```

## 环境变量说明

| 环境变量 | 说明 | 必需 |
|---------|------|------|
| `ORACLE_USERNAME` | Oracle数据库用户名 | 是 |
| `ORACLE_PASSWORD` | Oracle数据库密码 | 是 |
| `ORACLE_HOST` | Oracle数据库主机地址 | 是 |
| `ORACLE_PORT` | Oracle数据库端口 | 是 |
| `ORACLE_SERVICE` | Oracle数据库服务名 | 是 |

## 持久化环境变量

### 方法1：在 ~/.bashrc 中设置

```bash
echo 'export ORACLE_USERNAME=your_username' >> ~/.bashrc
echo 'export ORACLE_PASSWORD=your_password' >> ~/.bashrc
echo 'export ORACLE_HOST=your_host' >> ~/.bashrc
echo 'export ORACLE_PORT=1521' >> ~/.bashrc
echo 'export ORACLE_SERVICE=your_service_name' >> ~/.bashrc
source ~/.bashrc
```

### 方法2：使用环境文件（推荐用于systemd服务）

创建 `/etc/oracle-collector/env`：

```bash
ORACLE_USERNAME=your_username
ORACLE_PASSWORD=your_password
ORACLE_HOST=your_host
ORACLE_PORT=1521
ORACLE_SERVICE=your_service_name
```

然后在systemd服务文件中使用：

```ini
[Service]
EnvironmentFile=/etc/oracle-collector/env
```

### 方法3：使用AWS Secrets Manager（生产环境推荐）

参考 `SECURITY.md` 中的详细说明。

## 常用命令

```bash
# 启动服务
./oracle_collector_ctl.sh start

# 停止服务
./oracle_collector_ctl.sh stop

# 重启服务
./oracle_collector_ctl.sh restart

# 查看状态
./oracle_collector_ctl.sh status

# 查看日志
./oracle_collector_ctl.sh tail
```

## 文档

- [安装指南](INSTALL.md) - 详细的安装和配置说明
- [安全指南](SECURITY.md) - 敏感信息处理和安全最佳实践

## 注意事项

1. **敏感信息**：配置文件中的敏感信息已移除，必须通过环境变量设置
2. **文件权限**：确保配置文件权限设置正确（建议 `chmod 600 metrics_config.yaml`）
3. **日志文件**：日志文件默认在脚本目录下，定期检查日志文件大小

