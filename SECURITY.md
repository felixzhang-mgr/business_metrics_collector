# 安全配置指南

## 敏感信息处理

配置文件 `metrics_config.yaml` 已使用环境变量占位符，不包含敏感信息。所有敏感信息（数据库用户名、密码等）必须通过环境变量提供。

以下是在运行时提供敏感信息的几种方式：

## 方案1：使用环境变量（推荐）

### 配置方式

在配置文件中使用环境变量占位符：

```yaml
database:
  username: ${ORACLE_USERNAME}
  password: ${ORACLE_PASSWORD}
  host: ${ORACLE_HOST}
  port: ${ORACLE_PORT}
  service_name: ${ORACLE_SERVICE}
```

### 设置环境变量

```bash
# 方法1：在shell中设置（临时）
export ORACLE_USERNAME=PAYTEND_BI
export ORACLE_PASSWORD=PAYTEND_8!
export ORACLE_HOST=172.31.70.249
export ORACLE_PORT=1521
export ORACLE_SERVICE=PAYTEND

# 方法2：在 ~/.bashrc 或 ~/.bash_profile 中设置（持久化）
echo 'export ORACLE_USERNAME=PAYTEND_BI' >> ~/.bashrc
echo 'export ORACLE_PASSWORD=PAYTEND_8!' >> ~/.bashrc
echo 'export ORACLE_HOST=172.31.70.249' >> ~/.bashrc
echo 'export ORACLE_PORT=1521' >> ~/.bashrc
echo 'export ORACLE_SERVICE=PAYTEND' >> ~/.bashrc
source ~/.bashrc

# 方法3：使用 systemd 环境文件（如果配置为系统服务）
# 创建 /etc/oracle-collector/env
# ORACLE_USERNAME=PAYTEND_BI
# ORACLE_PASSWORD=PAYTEND_8!
# ...
```

### 支持格式

- `${VAR_NAME}` - 从环境变量读取，不存在则保持原样
- `${VAR_NAME:default_value}` - 从环境变量读取，不存在则使用默认值

示例：
```yaml
password: ${ORACLE_PASSWORD}              # 必须设置环境变量
port: ${ORACLE_PORT:1521}                 # 环境变量不存在时使用默认值1521
```

## 方案2：使用 AWS Secrets Manager（生产环境推荐）

### 安装 AWS CLI 和 boto3

```bash
pip3 install --user boto3
```

### 创建密钥

```bash
aws secretsmanager create-secret \
    --name oracle-db-credentials \
    --secret-string '{"username":"PAYTEND_BI","password":"PAYTEND_8!","host":"172.31.70.249","port":"1521","service_name":"PAYTEND"}'
```

### 修改代码读取密钥

可以在启动脚本中从 Secrets Manager 读取并设置环境变量：

```bash
#!/bin/bash
# 从 Secrets Manager 读取凭证
SECRET=$(aws secretsmanager get-secret-value --secret-id oracle-db-credentials --query SecretString --output text)
export ORACLE_USERNAME=$(echo $SECRET | jq -r .username)
export ORACLE_PASSWORD=$(echo $SECRET | jq -r .password)
export ORACLE_HOST=$(echo $SECRET | jq -r .host)
export ORACLE_PORT=$(echo $SECRET | jq -r .port)
export ORACLE_SERVICE=$(echo $SECRET | jq -r .service_name)

# 启动脚本
python3 oracle_metrics_collector.py
```

## 方案3：使用配置文件

配置文件 `metrics_config.yaml` 已包含在项目中，使用环境变量占位符。

### 设置文件权限

```bash
# 限制文件权限，只有所有者可读写（可选，因为不包含敏感信息）
chmod 600 metrics_config.yaml
```

## 最佳实践

1. **不要将敏感信息提交到版本控制系统**
   - `metrics_config.yaml` 已使用环境变量占位符，不包含敏感信息
   - 可以直接提交到版本控制

2. **使用环境变量或密钥管理服务**
   - 开发环境：使用环境变量
   - 生产环境：使用 AWS Secrets Manager 或类似服务

3. **限制文件权限**
   ```bash
   chmod 600 metrics_config.yaml  # 只有所有者可读写
   ```

4. **定期轮换密码**
   - 定期更新数据库密码
   - 更新环境变量或 Secrets Manager 中的值

5. **使用 IAM 角色**
   - EC2 实例使用 IAM 角色访问 Secrets Manager
   - 避免在代码中硬编码 AWS 凭证

## 当前配置检查

检查当前配置是否包含敏感信息：

```bash
# 检查配置文件是否在版本控制中
git check-ignore metrics_config.yaml

# 检查文件权限
ls -l metrics_config.yaml

# 检查环境变量是否设置
env | grep ORACLE
```

## 迁移步骤

如果当前配置文件中包含敏感信息：

1. **立即从版本控制中移除**
   ```bash
   git rm --cached metrics_config.yaml
   git commit -m "Remove sensitive config file"
   ```

2. **设置环境变量**
   ```bash
   export ORACLE_USERNAME=your_username
   export ORACLE_PASSWORD=your_password
   # ... 其他变量
   ```

3. **更新配置文件使用环境变量**
   ```yaml
   database:
     username: ${ORACLE_USERNAME}
     password: ${ORACLE_PASSWORD}
     # ...
   ```

4. **验证配置**
   ```bash
   python3 oracle_metrics_collector.py --config metrics_config.yaml --log-level DEBUG
   ```

