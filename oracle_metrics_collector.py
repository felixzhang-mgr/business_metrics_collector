#!/usr/bin/env python3
"""
Oracle数据库指标采集脚本
通过SQL查询采集Oracle数据库指标，并将结果发送到AWS CloudWatch

Cron表达式说明：
Cron表达式格式：分 时 日 月 周
- 分：0-59
- 时：0-23
- 日：1-31
- 月：1-12
- 周：0-6 (0=周日)

示例：
- "*/1 * * * *"  - 每分钟执行一次
- "*/5 * * * *"  - 每5分钟执行一次
- "0 * * * *"    - 每小时执行一次
- "0 */2 * * *"  - 每2小时执行一次
- "0 0 * * *"    - 每天午夜执行
- "0 9 * * 1-5"  - 工作日上午9点执行
"""

import sys
import os
import time
import argparse
import boto3
import threading
import logging
from datetime import datetime, timezone
from typing import List, Dict, Callable, Any, Optional
from collections import deque
from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeoutError

try:
    import yaml
except ImportError:
    print("错误：需要安装PyYAML库")
    print("安装命令：pip install PyYAML")
    sys.exit(1)

try:
    import oracledb
except ImportError:
    try:
        import cx_Oracle as oracledb
    except ImportError:
        print("错误：需要安装Oracle数据库连接库")
        print("安装命令：pip install oracledb")
        print("或者：pip install cx_Oracle")
        print("注意：还需要安装Oracle Instant Client")
        sys.exit(1)

try:
    from croniter import croniter
except ImportError:
    print("错误：需要安装croniter库")
    print("安装命令：pip install croniter")
    sys.exit(1)


# 全局日志对象（在setup_logging中初始化）
logger = None


def setup_logging(log_file: Optional[str] = None, log_level: str = 'INFO'):
    """
    配置日志系统
    
    Args:
        log_file: 日志文件路径，None表示使用默认路径（脚本目录下的oracle_collector.log）
        log_level: 日志级别（DEBUG, INFO, WARNING, ERROR）
    
    Returns:
        logging.Logger: 日志对象
    """
    global logger
    
    # 确定日志文件路径
    if log_file is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        log_file = os.path.join(script_dir, 'oracle_collector.log')
    
    # 配置日志格式
    log_format = '%(asctime)s [%(levelname)s] [%(threadName)s] %(message)s'
    date_format = '%Y-%m-%d %H:%M:%S'
    
    # 配置日志
    logging.basicConfig(
        level=getattr(logging, log_level.upper(), logging.INFO),
        format=log_format,
        datefmt=date_format,
        handlers=[
            logging.FileHandler(log_file, encoding='utf-8'),
            # 不添加控制台处理器，保持"不在控制台打印"的要求
        ],
        force=True  # 允许重新配置日志
    )
    
    logger = logging.getLogger(__name__)
    return logger


@dataclass
class DataPoint:
    """数据点，包含值和时间戳"""
    value: float
    timestamp: datetime


class MetricValueConverter:
    """
    指标值转换器基类
    支持状态保持的复杂转换逻辑，如聚合函数
    """
    
    def __init__(self, max_history_size: int = 100):
        """
        初始化转换器
        
        Args:
            max_history_size: 最大历史数据点数量
        """
        self.max_history_size = max_history_size
        self.history: deque = deque(maxlen=max_history_size)
    
    def convert(self, raw_value: Optional[float], timestamp: datetime) -> Optional[float]:
        """
        转换原始值为指标值
        
        Args:
            raw_value: SQL查询返回的原始值
            timestamp: 当前时间戳
            
        Returns:
            float: 转换后的指标值，如果无法转换返回None
        """
        if raw_value is None:
            return None
        
        # 添加新数据点到历史记录
        self.history.append(DataPoint(value=float(raw_value), timestamp=timestamp))
        
        # 子类应重写此方法实现具体转换逻辑
        return raw_value
    
    def get_history_values(self) -> List[float]:
        """获取历史值列表"""
        return [dp.value for dp in self.history]


class SimpleConverter(MetricValueConverter):
    """
    简单转换器，直接返回原始值或应用简单函数
    """
    
    def __init__(self, converter_func: Optional[Callable[[float], float]] = None):
        """
        初始化简单转换器
        
        Args:
            converter_func: 可选的转换函数
        """
        super().__init__(max_history_size=1)
        self.converter_func = converter_func
    
    def convert(self, raw_value: Optional[float], timestamp: datetime) -> Optional[float]:
        if raw_value is None:
            return None
        
        value = float(raw_value)
        if self.converter_func:
            return self.converter_func(value)
        return value


class AvgConverter(MetricValueConverter):
    """
    平均值转换器：计算历史数据的平均值
    """
    
    def convert(self, raw_value: Optional[float], timestamp: datetime) -> Optional[float]:
        super().convert(raw_value, timestamp)
        
        if len(self.history) == 0:
            return None
        
        values = self.get_history_values()
        return sum(values) / len(values)


class MaxConverter(MetricValueConverter):
    """
    最大值转换器：返回历史数据的最大值
    """
    
    def convert(self, raw_value: Optional[float], timestamp: datetime) -> Optional[float]:
        super().convert(raw_value, timestamp)
        
        if len(self.history) == 0:
            return None
        
        return max(self.get_history_values())


class MinConverter(MetricValueConverter):
    """
    最小值转换器：返回历史数据的最小值
    """
    
    def convert(self, raw_value: Optional[float], timestamp: datetime) -> Optional[float]:
        super().convert(raw_value, timestamp)
        
        if len(self.history) == 0:
            return None
        
        return min(self.get_history_values())


class SumConverter(MetricValueConverter):
    """
    求和转换器：计算历史数据的总和
    """
    
    def convert(self, raw_value: Optional[float], timestamp: datetime) -> Optional[float]:
        super().convert(raw_value, timestamp)
        
        if len(self.history) == 0:
            return None
        
        return sum(self.get_history_values())


class RateConverter(MetricValueConverter):
    """
    速率转换器：计算指标的变化速率（每秒）
    类似PromQL的rate()函数
    """
    
    def __init__(self, max_history_size: int = 2):
        """
        初始化速率转换器
        
        Args:
            max_history_size: 只需要最近2个数据点计算速率
        """
        super().__init__(max_history_size=max_history_size)
    
    def convert(self, raw_value: Optional[float], timestamp: datetime) -> Optional[float]:
        super().convert(raw_value, timestamp)
        
        # 需要至少2个数据点才能计算速率
        if len(self.history) < 2:
            return None
        
        # 获取最近两个数据点
        dp1 = self.history[-2]
        dp2 = self.history[-1]
        
        # 计算时间差（秒）
        time_diff = (dp2.timestamp - dp1.timestamp).total_seconds()
        if time_diff <= 0:
            return None
        
        # 计算速率：值的变化量 / 时间差
        value_diff = dp2.value - dp1.value
        rate = value_diff / time_diff
        
        return rate


class IncreaseConverter(MetricValueConverter):
    """
    增量转换器：计算指标的总增量
    类似PromQL的increase()函数
    """
    
    def __init__(self, max_history_size: int = 2):
        """
        初始化增量转换器
        
        Args:
            max_history_size: 只需要最近2个数据点计算增量
        """
        super().__init__(max_history_size=max_history_size)
    
    def convert(self, raw_value: Optional[float], timestamp: datetime) -> Optional[float]:
        super().convert(raw_value, timestamp)
        
        # 需要至少2个数据点才能计算增量
        if len(self.history) < 2:
            return None
        
        # 获取最近两个数据点
        dp1 = self.history[-2]
        dp2 = self.history[-1]
        
        # 计算增量
        increase = dp2.value - dp1.value
        
        # 如果值可能重置（计数器重置），处理负值情况
        # 对于计数器类型，如果新值小于旧值，可能是重置，返回0
        if increase < 0:
            # 可以返回0或绝对值，取决于业务逻辑
            # 这里返回0，表示没有增量
            return 0.0
        
        return increase


class MetricConfig:
    """
    指标配置类
    定义每个指标的采集规则
    """
    
    def __init__(
        self,
        metric_name: str,
        sql_query: str,
        namespace: str,
        dimensions: List[Dict[str, str]],
        value_converter: Optional[Any] = None,
        unit: str = 'None',
        query_timeout: Optional[float] = None,
        cron_expr: Optional[str] = None
    ):
        """
        初始化指标配置
        
        Args:
            metric_name: CloudWatch指标名称
            sql_query: 用于采集指标的SQL查询，应返回单个数值
            namespace: CloudWatch命名空间
            dimensions: CloudWatch维度列表
            value_converter: 可选的值转换器，可以是：
                - MetricValueConverter实例（支持聚合函数）
                - Callable函数（简单转换）
                - None（直接使用原始值）
            unit: 指标单位（默认：'None'）
            query_timeout: 查询超时时间（秒），None表示使用默认值（30秒）
            cron_expr: Cron表达式，None表示使用默认值（*/1 * * * *，即每分钟）
        """
        self.metric_name = metric_name
        self.sql_query = sql_query
        self.namespace = namespace
        self.dimensions = dimensions
        self.value_converter = value_converter
        self.unit = unit
        self.query_timeout = query_timeout
        self.cron_expr = cron_expr


class OracleConnectionPool:
    """
    Oracle数据库连接池管理器（线程安全）
    用于管理多个数据库连接，支持并发访问
    """
    
    def __init__(self, username, password, host, port, service_name, 
                 max_connections: int = 10, default_query_timeout: float = 30.0):
        """
        初始化连接池
        
        Args:
            username: 数据库用户名
            password: 数据库密码
            host: 数据库主机
            port: 数据库端口
            service_name: 服务名
            max_connections: 最大连接数
            default_query_timeout: 默认查询超时时间（秒）
        """
        self.username = username
        self.password = password
        self.host = host
        self.port = port
        self.service_name = service_name
        self.dsn = f"{host}:{port}/{service_name}"
        self.max_connections = max_connections
        self.default_query_timeout = default_query_timeout
        
        # 线程安全的连接池
        self._pool = []  # 可用连接列表
        self._lock = threading.Lock()  # 保护连接池的锁
        self._active_connections = 0  # 当前活跃连接数
    
    def _create_connection(self):
        """创建新的数据库连接"""
        try:
            conn = oracledb.connect(
                user=self.username,
                password=self.password,
                dsn=self.dsn
            )
            if logger:
                logger.debug(f"创建新数据库连接成功，当前活跃连接数: {self._active_connections + 1}")
            return conn
        except Exception as e:
            if logger:
                logger.error(f"创建数据库连接失败: {e}")
            return None
    
    def _validate_connection(self, connection):
        """验证连接是否有效"""
        if connection is None:
            return False
        try:
            cursor = connection.cursor()
            cursor.execute("SELECT 1 FROM DUAL")
            cursor.fetchone()
            cursor.close()
            return True
        except Exception as e:
            if logger:
                logger.debug(f"连接验证失败: {e}")
            return False
    
    def get_connection(self):
        """
        从连接池获取数据库连接（线程安全）
        
        Returns:
            tuple: (connection, is_valid) 元组，is_valid表示连接是否有效
        """
        with self._lock:
            # 尝试从池中获取可用连接
            while self._pool:
                conn = self._pool.pop()
                if self._validate_connection(conn):
                    return conn, True
                else:
                    # 连接已失效，关闭它并减少计数
                    try:
                        conn.close()
                    except Exception:
                        pass
                    self._active_connections -= 1
            
            # 池中没有可用连接，检查是否可以创建新连接
            if self._active_connections < self.max_connections:
                conn = self._create_connection()
                if conn:
                    self._active_connections += 1
                    return conn, True
            else:
                if logger:
                    logger.warning(f"连接池已满，无法创建新连接（当前: {self._active_connections}/{self.max_connections}）")
            
            # 无法获取连接，返回None
            if logger:
                logger.warning("无法从连接池获取连接")
            return None, False
    
    def return_connection(self, connection):
        """
        将连接返回到连接池（线程安全）
        
        Args:
            connection: 要返回的连接
        """
        if connection is None:
            return
        
        with self._lock:
            # 验证连接是否有效
            if self._validate_connection(connection):
                # 连接有效，放回池中
                self._pool.append(connection)
                if logger:
                    logger.debug(f"连接已归还到池中，当前池大小: {len(self._pool)}, 活跃连接: {self._active_connections}")
            else:
                # 连接无效，关闭它并减少计数
                if logger:
                    logger.warning("连接已失效，关闭并移除")
                try:
                    connection.close()
                except Exception:
                    pass
                self._active_connections -= 1
    
    def execute_query(self, sql_query: str, timeout: Optional[float] = None) -> Optional[float]:
        """
        执行SQL查询并返回结果（带超时保护，线程安全）
        
        Args:
            sql_query: SQL查询语句，应返回单个数值
            timeout: 查询超时时间（秒），None表示使用默认值
            
        Returns:
            float: 查询结果，如果查询失败或超时返回None
        """
        if timeout is None:
            timeout = self.default_query_timeout
        
        connection = None
        cursor = None
        
        try:
            # 从连接池获取连接
            connection, is_valid = self.get_connection()
            if not is_valid or connection is None:
                if logger:
                    logger.warning(f"无法获取数据库连接，查询失败: {sql_query[:50]}...")
                return None
            
            def _execute_query():
                """执行查询的内部函数"""
                nonlocal cursor
                try:
                    cursor = connection.cursor()
                    cursor.execute(sql_query)
                    result = cursor.fetchone()
                    
                    # 提取第一个值（假设查询返回单行单列）
                    if result and len(result) > 0:
                        return float(result[0])
                    return None
                except Exception:
                    return None
            
            # 使用ThreadPoolExecutor实现超时控制
            query_start_time = time.time()
            with ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(_execute_query)
                try:
                    result = future.result(timeout=timeout)
                    query_duration = time.time() - query_start_time
                    if logger:
                        if query_duration > 1.0:
                            logger.warning(f"慢查询检测: 耗时 {query_duration:.2f}秒, SQL: {sql_query[:100]}...")
                        else:
                            logger.debug(f"查询成功，耗时 {query_duration:.2f}秒")
                    return result
                except FutureTimeoutError:
                    # 查询超时
                    if logger:
                        logger.warning(f"查询超时（{timeout}秒）: {sql_query[:100]}...")
                    return None
        except Exception as e:
            if logger:
                logger.error(f"查询执行异常: {e}, SQL: {sql_query[:100]}...")
            return None
        finally:
            # 清理资源并返回连接
            if cursor:
                try:
                    cursor.close()
                except Exception:
                    pass
            if connection:
                self.return_connection(connection)
    
    def close(self):
        """
        关闭所有连接池中的连接
        注意：正在使用的连接会在使用完毕后自动归还并关闭
        """
        with self._lock:
            for conn in self._pool:
                try:
                    conn.close()
                except Exception:
                    pass
            self._pool.clear()
            # 注意：_active_connections可能大于0（有连接正在使用），
            # 但这些连接会在使用完毕后通过return_connection归还，然后被关闭
            # 或者等待线程结束自然关闭
            self._active_connections = 0


def validate_cron_expression(cron_expr):
    """
    验证cron表达式是否有效
    
    Args:
        cron_expr: cron表达式字符串
        
    Returns:
        bool: 如果有效返回True，否则返回False
    """
    try:
        # 尝试创建croniter对象来验证表达式
        croniter(cron_expr)
        return True
    except Exception:
        return False


class CloudWatchMetrics:
    """
    CloudWatch指标发送器
    用于重用CloudWatch客户端，减少内存占用
    """
    
    def __init__(self):
        """
        初始化CloudWatch客户端
        """
        self.cloudwatch = boto3.client('cloudwatch', region_name='us-central-1')
    
    def send_metric(
        self,
        metric_name: str,
        value: float,
        namespace: str,
        dimensions: List[Dict[str, str]],
        unit: str = 'None'
    ):
        """
        将指标发送到AWS CloudWatch
        
        Args:
            metric_name: 指标名称
            value: 指标值
            namespace: 命名空间
            dimensions: 维度列表
            unit: 指标单位
        """
        try:
            self.cloudwatch.put_metric_data(
                Namespace=namespace,
                MetricData=[
                    {
                        'MetricName': metric_name,
                        'Dimensions': dimensions,
                        'Value': value,
                        'Timestamp': datetime.now(timezone.utc),
                        'Unit': unit
                    }
                ]
            )
            if logger:
                logger.debug(f"指标发送成功: {metric_name}={value}, namespace={namespace}")
        except Exception as e:
            if logger:
                logger.error(f"指标发送失败: {metric_name}, 错误: {e}")


def create_converter_from_config(converter_config: Optional[Dict]) -> Optional[Any]:
    """
    根据配置创建转换器实例
    
    Args:
        converter_config: 转换器配置字典
        
    Returns:
        转换器实例，如果配置为None则返回None
    """
    if converter_config is None:
        return None
    
    converter_type = converter_config.get('type', 'simple')
    max_history_size = converter_config.get('max_history_size', 100)
    
    if converter_type == 'simple':
        # 简单转换器，支持lambda函数
        func_str = converter_config.get('func')
        if func_str:
            # 警告：使用eval执行lambda表达式，存在安全风险
            # 仅当配置文件完全可信时使用，生产环境建议使用预定义的转换函数
            try:
                func = eval(func_str)
                return SimpleConverter(func)
            except Exception:
                if logger:
                    logger.warning(f"转换器函数解析失败: {func_str}")
                return None
        return None
    elif converter_type == 'avg':
        return AvgConverter(max_history_size=max_history_size)
    elif converter_type == 'max':
        return MaxConverter(max_history_size=max_history_size)
    elif converter_type == 'min':
        return MinConverter(max_history_size=max_history_size)
    elif converter_type == 'sum':
        return SumConverter(max_history_size=max_history_size)
    elif converter_type == 'rate':
        return RateConverter(max_history_size=2)
    elif converter_type == 'increase':
        return IncreaseConverter(max_history_size=2)
    else:
        return None


def load_config_file(config_file: str = 'metrics_config.yaml') -> Dict:
    """
    加载配置文件
    
    Args:
        config_file: 配置文件路径（默认：metrics_config.yaml）
        
    Returns:
        Dict: 配置数据字典
    """
    # 获取配置文件路径
    if not os.path.isabs(config_file):
        # 相对路径，使用脚本所在目录
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_path = os.path.join(script_dir, config_file)
    else:
        config_path = config_file
    
    # 读取配置文件
    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config_data = yaml.safe_load(f)
    except FileNotFoundError:
        print(f"错误：配置文件不存在：{config_path}")
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"错误：配置文件格式错误：{e}")
        sys.exit(1)
    
    return config_data


def format_dimension(dim: Any) -> Optional[Dict[str, str]]:
    """
    格式化单个维度为字典格式
    
    Args:
        dim: 维度数据，可以是字典或列表
        
    Returns:
        Dict[str, str]: 格式化后的维度字典，如果格式不正确返回None
    """
    if isinstance(dim, dict):
        return dim
    elif isinstance(dim, list) and len(dim) == 2:
        return {'Name': dim[0], 'Value': dim[1]}
    return None


def merge_dimensions(common_dimensions: List[Any], custom_dimensions: List[Any]) -> List[Dict[str, str]]:
    """
    合并公共维度和自定义维度
    
    Args:
        common_dimensions: 公共维度列表
        custom_dimensions: 自定义维度列表
        
    Returns:
        List[Dict[str, str]]: 合并后的维度列表
    """
    # 将公共维度转换为字典（以Name为key）
    dimensions_dict = {}
    for dim in common_dimensions:
        formatted_dim = format_dimension(dim)
        if formatted_dim:
            dimensions_dict[formatted_dim['Name']] = formatted_dim['Value']
    
    # 合并自定义维度（同名时优先使用自定义维度的值）
    for dim in custom_dimensions:
        formatted_dim = format_dimension(dim)
        if formatted_dim:
            dimensions_dict[formatted_dim['Name']] = formatted_dim['Value']
    
    # 转换回列表格式
    return [{'Name': name, 'Value': value} for name, value in dimensions_dict.items()]


def get_metric_configs(config_file: str = 'metrics_config.yaml') -> List[MetricConfig]:
    """
    从配置文件读取指标配置
    
    Args:
        config_file: 配置文件路径（默认：metrics_config.yaml）
        
    Returns:
        List[MetricConfig]: 指标配置列表
    """
    config_data = load_config_file(config_file)
    
    # 获取公共维度
    common_dimensions = config_data.get('common_dimensions', [])
    
    # 解析指标配置
    metrics_config = config_data.get('metrics', [])
    configs = []
    
    for metric in metrics_config:
        # 获取自定义维度并合并
        custom_dimensions = metric.get('dimensions', [])
        dimensions = merge_dimensions(common_dimensions, custom_dimensions)
        
        # 创建转换器
        converter_config = metric.get('converter')
        converter = create_converter_from_config(converter_config)
        
        # 获取查询超时时间（秒），None表示使用默认值
        query_timeout = metric.get('query_timeout')
        if query_timeout is not None:
            query_timeout = float(query_timeout)
        
        # 获取Cron表达式，None表示使用默认值（*/1 * * * *）
        cron_expr = metric.get('cron', '*/1 * * * *')
        
        # 创建指标配置
        config = MetricConfig(
            metric_name=metric['metric_name'],
            sql_query=metric['sql_query'],
            namespace=metric['namespace'],
            dimensions=dimensions,
            value_converter=converter,
            unit=metric.get('unit', 'None'),
            query_timeout=query_timeout,
            cron_expr=cron_expr
        )
        configs.append(config)
    
    return configs


def merge_metric_configs(
    new_configs: List[MetricConfig],
    converter_registry: Dict[str, MetricValueConverter]
) -> List[MetricConfig]:
    """
    合并新的指标配置和已有的转换器状态（保持转换器历史数据）
    注意：每个指标使用独立的转换器实例，不共享状态
    
    Args:
        new_configs: 新获取的指标配置列表
        converter_registry: 转换器注册表，以指标名称为key
        
    Returns:
        List[MetricConfig]: 合并后的指标配置列表（保持转换器状态）
    """
    merged_configs = []
    
    for config in new_configs:
        # 如果配置中有转换器且是MetricValueConverter类型
        if isinstance(config.value_converter, MetricValueConverter):
            # 检查是否已有该指标的转换器实例
            if config.metric_name in converter_registry:
                # 复用已有的转换器实例（保持历史数据）
                # 注意：每个指标独立转换器，不共享
                config.value_converter = converter_registry[config.metric_name]
            else:
                # 创建新的转换器实例并注册
                converter_registry[config.metric_name] = config.value_converter
        
        merged_configs.append(config)
    
    # 清理不再存在的指标的转换器（节省内存）
    existing_metric_names = {config.metric_name for config in new_configs}
    metrics_to_remove = [
        name for name in converter_registry.keys()
        if name not in existing_metric_names
    ]
    for name in metrics_to_remove:
        del converter_registry[name]
    
    return merged_configs


def collect_single_metric(
    config: MetricConfig,
    connection_pool: OracleConnectionPool,
    cloudwatch_metrics: CloudWatchMetrics
):
    """
    采集单个指标（线程安全，每个指标独立转换器）
    
    Args:
        config: 指标配置
        connection_pool: 数据库连接池
        cloudwatch_metrics: CloudWatch指标发送器
    """
    current_time = datetime.now(timezone.utc)
    
    try:
        if logger:
            logger.debug(f"开始采集指标: {config.metric_name}")
        
        # 执行SQL查询获取指标值（带超时保护）
        raw_value = connection_pool.execute_query(
            config.sql_query,
            timeout=config.query_timeout
        )
        
        if raw_value is None:
            if logger:
                logger.warning(f"指标查询返回None: {config.metric_name}, SQL: {config.sql_query[:100]}...")
        
        # 应用值转换器（如果存在）
        # 注意：每个指标使用独立的转换器实例，不共享状态
        if config.value_converter is None:
            # 没有转换器，直接使用原始值
            metric_value = raw_value if raw_value is not None else 0.0
        elif isinstance(config.value_converter, MetricValueConverter):
            # 使用转换器对象（支持聚合函数）
            metric_value = config.value_converter.convert(raw_value, current_time)
            if metric_value is None:
                if logger:
                    logger.debug(f"转换器返回None（可能需要更多数据点）: {config.metric_name}")
                return  # 跳过无法转换的值（如rate/increase需要至少2个数据点）
        elif callable(config.value_converter):
            # 使用简单转换函数（向后兼容）
            if raw_value is None:
                metric_value = 0.0
            else:
                metric_value = config.value_converter(raw_value)
        else:
            # 未知类型，使用原始值
            metric_value = raw_value if raw_value is not None else 0.0
        
        # 发送指标到CloudWatch
        cloudwatch_metrics.send_metric(
            metric_name=config.metric_name,
            value=metric_value,
            namespace=config.namespace,
            dimensions=config.dimensions,
            unit=config.unit
        )
        
        if logger:
            logger.info(f"指标采集成功: {config.metric_name}={metric_value}")
    except Exception as e:
        # 单个指标采集失败不影响其他指标
        if logger:
            logger.error(f"指标采集失败: {config.metric_name}, 错误: {e}", exc_info=True)


def run_single_metric_scheduler(
    config: MetricConfig,
    connection_pool: OracleConnectionPool,
    cloudwatch_metrics: CloudWatchMetrics,
    converter_registry: Dict[str, MetricValueConverter],
    config_file: str
):
    """
    单个指标的独立调度器
    
    Args:
        config: 指标配置
        connection_pool: 数据库连接池
        cloudwatch_metrics: CloudWatch指标发送器
        converter_registry: 转换器注册表
        config_file: 配置文件路径
    """
    # 验证cron表达式
    if not validate_cron_expression(config.cron_expr):
        if logger:
            logger.error(f"指标 {config.metric_name} 的cron表达式无效: {config.cron_expr}")
            logger.error("Cron表达式格式：分 时 日 月 周")
            logger.error("示例：*/1 * * * * (每分钟), */5 * * * * (每5分钟), 0 * * * * (每小时)")
        return
    
    # 创建cron迭代器
    cron = croniter(config.cron_expr, datetime.now())
    
    try:
        if logger:
            logger.info(f"启动指标调度器: {config.metric_name}, cron={config.cron_expr}")
        
        # 首次立即执行一次采集
        collect_single_metric(config, connection_pool, cloudwatch_metrics)
        
        while True:
            # 获取当前时间
            current_time = datetime.now()
            # 获取下次执行时间
            next_time = cron.get_next(current_time)
            
            # 计算需要等待的秒数
            wait_seconds = (next_time - current_time).total_seconds()
            
            # 如果等待时间大于0，则等待
            if wait_seconds > 0:
                if logger:
                    logger.debug(f"指标 {config.metric_name} 等待 {wait_seconds:.1f}秒后执行")
                time.sleep(wait_seconds)
            
            # 重新加载配置（支持动态配置更新）
            try:
                new_configs = get_metric_configs(config_file)
                # 使用字典查找提高效率
                config_dict = {cfg.metric_name: cfg for cfg in new_configs}
                updated_config = config_dict.get(config.metric_name)
                
                if updated_config:
                    # 更新配置但保持转换器状态
                    if isinstance(updated_config.value_converter, MetricValueConverter):
                        if config.metric_name in converter_registry:
                            updated_config.value_converter = converter_registry[config.metric_name]
                        else:
                            converter_registry[config.metric_name] = updated_config.value_converter
                    
                    # 更新cron表达式（如果改变）
                    old_cron_expr = config.cron_expr
                    config = updated_config
                    if config.cron_expr != old_cron_expr:
                        if logger:
                            logger.info(f"指标 {config.metric_name} cron表达式已更新: {old_cron_expr} -> {config.cron_expr}")
                        cron = croniter(config.cron_expr, datetime.now())
            except Exception as e:
                if logger:
                    logger.warning(f"配置加载失败，继续使用旧配置: {config.metric_name}, 错误: {e}")
            
            # 执行指标采集
            collect_single_metric(config, connection_pool, cloudwatch_metrics)
            
    except KeyboardInterrupt:
        if logger:
            logger.info(f"指标调度器停止: {config.metric_name}")
    except Exception as e:
        if logger:
            logger.error(f"指标调度器异常退出: {config.metric_name}, 错误: {e}", exc_info=True)


def run_periodic_check(config_file: str = 'metrics_config.yaml', log_file: Optional[str] = None, log_level: str = 'INFO'):
    """
    启动所有指标的独立调度器
    每个指标根据其cron表达式独立调度
    
    Args:
        config_file: 配置文件路径
        log_file: 日志文件路径，None表示使用默认路径
        log_level: 日志级别（DEBUG, INFO, WARNING, ERROR）
    """
    # 初始化日志系统
    global logger
    logger = setup_logging(log_file, log_level)
    logger.info("=" * 60)
    logger.info("Oracle指标采集脚本启动")
    logger.info(f"配置文件: {config_file}")
    logger.info(f"日志级别: {log_level}")
    
    # 从环境变量读取数据库连接参数（必需）
    username = os.getenv('ORACLE_USERNAME')
    password = os.getenv('ORACLE_PASSWORD')
    host = os.getenv('ORACLE_HOST')
    port = os.getenv('ORACLE_PORT', '1521')
    service_name = os.getenv('ORACLE_SERVICE')
    
    # 验证必需的环境变量
    if not all([username, password, host, service_name]):
        missing_vars = []
        if not username:
            missing_vars.append('ORACLE_USERNAME')
        if not password:
            missing_vars.append('ORACLE_PASSWORD')
        if not host:
            missing_vars.append('ORACLE_HOST')
        if not service_name:
            missing_vars.append('ORACLE_SERVICE')
        
        error_msg = f"错误：缺少必需的环境变量: {', '.join(missing_vars)}"
        if logger:
            logger.error(error_msg)
        print(error_msg)
        print("请在运行前设置以下环境变量：")
        print("  export ORACLE_USERNAME=your_username")
        print("  export ORACLE_PASSWORD=your_password")
        print("  export ORACLE_HOST=your_host")
        print("  export ORACLE_PORT=1521  # 可选，默认1521")
        print("  export ORACLE_SERVICE=your_service_name")
        sys.exit(1)
    
    # 从配置文件读取数据库连接池配置（可选）
    config_data = load_config_file(config_file)
    db_config = config_data.get('database', {})
    max_connections = db_config.get('max_connections', 10)
    default_query_timeout = float(db_config.get('default_query_timeout', 30.0))
    
    # 注意：日志中不输出敏感信息（用户名、密码）
    logger.info(f"数据库连接: {host}:{port}/{service_name}, 最大连接数: {max_connections}")
    
    # 创建连接池
    connection_pool = OracleConnectionPool(
        username, password, host, port, service_name, max_connections, default_query_timeout
    )
    
    # 创建CloudWatch指标发送器
    cloudwatch_metrics = CloudWatchMetrics()
    
    # 转换器注册表，用于保持转换器状态（历史数据）
    converter_registry: Dict[str, MetricValueConverter] = {}
    
    # 调度器线程列表
    scheduler_threads = []
    
    try:
        # 加载指标配置
        logger.info("加载指标配置...")
        metric_configs = get_metric_configs(config_file)
        metric_configs = merge_metric_configs(metric_configs, converter_registry)
        logger.info(f"成功加载 {len(metric_configs)} 个指标配置")
        
        # 为每个指标创建独立的调度器线程
        for config in metric_configs:
            thread = threading.Thread(
                target=run_single_metric_scheduler,
                args=(config, connection_pool, cloudwatch_metrics, converter_registry, config_file),
                daemon=True,
                name=f"Scheduler-{config.metric_name}"
            )
            thread.start()
            scheduler_threads.append(thread)
            logger.info(f"已启动指标调度器: {config.metric_name}")
        
        logger.info(f"所有调度器已启动，共 {len(scheduler_threads)} 个指标")
        logger.info("=" * 60)
        
        # 等待所有调度器线程（实际上会一直运行）
        for thread in scheduler_threads:
            thread.join()
            
    except KeyboardInterrupt:
        # 优雅退出
        logger.info("收到中断信号，正在关闭...")
    except Exception as e:
        logger.error(f"程序异常退出: {e}", exc_info=True)
    finally:
        # 关闭连接池
        logger.info("关闭数据库连接池...")
        connection_pool.close()
        logger.info("程序已退出")


def main():
    """
    主函数：解析参数并执行指标采集
    """
    parser = argparse.ArgumentParser(
        description='Oracle数据库指标采集脚本',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
注意：每个指标的cron表达式在配置文件中单独配置
Cron表达式格式：分 时 日 月 周
示例：
  */1 * * * *   - 每分钟执行一次（默认）
  */5 * * * *   - 每5分钟执行一次
  0 * * * *     - 每小时执行一次
  0 9 * * 1-5   - 工作日上午9点执行
        """
    )
    
    parser.add_argument(
        '--config',
        type=str,
        default='metrics_config.yaml',
        help='指标配置文件路径（默认：metrics_config.yaml）'
    )
    
    parser.add_argument(
        '--log-file',
        type=str,
        default=None,
        help='日志文件路径（默认：脚本目录下的oracle_collector.log）'
    )
    
    parser.add_argument(
        '--log-level',
        type=str,
        default='INFO',
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        help='日志级别（默认：INFO）'
    )
    
    args = parser.parse_args()
    
    # 执行周期性指标采集（每个指标独立调度）
    run_periodic_check(args.config, args.log_file, args.log_level)


if __name__ == '__main__':
    main()

