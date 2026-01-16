AWS_PROFILE=admin aws dms describe-replication-tasks --filters Name=replication-task-id,Values=paytend-oracle-to-legacydb-cdc-2026-01-08 > paytend-oracle-to-legacydb-cdc-2026-01-08.json

AWS_PROFILE=admin aws dms create-replication-task --cli-input-json file://cdc-task-temple.json

#create replication config
aws dms create-replication-config --profile admin \
--replication-config-identifier paytend-oracle-to-legacydb-cdc-2026-01-16 \
--source-endpoint-arn arn:aws:dms:eu-central-1:144523794490:endpoint:RDFPBKFD5BBNXKHXOMSVLSMES4 \
--target-endpoint-arn arn:aws:dms:eu-central-1:144523794490:endpoint:M3B4FOCDBRF7HL4CLWSTAJULIQ \
--compute-config '{
  "MaxCapacityUnits": 4,
  "MultiAZ": false,
  "ReplicationSubnetGroupId": "default-vpc-21668c4b",
  "VpcSecurityGroupIds": ["sg-0652248686570dc3d","sg-02e13ff9978ee3ea7"]
}' \
--replication-type cdc \
--table-mappings '{
    "rules": [
        {
            "rule-id": 2048868916,
            "rule-name": "mj9vmcbg-lyk7x6",
            "rule-type": "selection",
            "rule-action": "include",
            "object-locator": {
                "schema-name": "PAYTEND",
                "table-name": "TBL_TRIBECARDAUTHORIZATION"
            },
            "filters": []
        },
        {
            "rule-id": 3390996,
            "rule-name": "mj9vnfqh-cajnsk",
            "rule-type": "selection",
            "rule-action": "include",
            "object-locator": {
                "schema-name": "PAYTEND",
                "table-name": "TBL_TRADE"
            },
            "filters": []
        },
        {
            "rule-id": 37377646,
            "rule-name": "mj9vnstd-0j0kbo",
            "rule-type": "selection",
            "rule-action": "include",
            "object-locator": {
                "schema-name": "PAYTEND",
                "table-name": "TBL_USER"
            },
            "filters": []
        },
        {
            "rule-id": 982932666,
            "rule-name": "mjc6rv81-yo65k1",
            "rule-type": "selection",
            "rule-action": "include",
            "object-locator": {
                "schema-name": "PAYTEND",
                "table-name": "TBL_INVENTI_WEBHOOK_LOG"
            },
            "filters": []
        }
    ]
}' \
--replication-settings '{
  "Logging": {
    "EnableLogging": true,
    "EnableLogContext": true,
    "LogComponents": [
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "TRANSFORMATION" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "SOURCE_UNLOAD" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "IO" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "TARGET_LOAD" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "PERFORMANCE" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "SOURCE_CAPTURE" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "SORTER" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "REST_SERVER" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "VALIDATOR_EXT" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "TARGET_APPLY" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "TASK_MANAGER" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "TABLES_MANAGER" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "METADATA_MANAGER" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "FILE_FACTORY" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "COMMON" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "ADDONS" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "DATA_STRUCTURE" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "COMMUNICATION" },
      { "Severity": "LOGGER_SEVERITY_DEFAULT", "Id": "FILE_TRANSFER" }
    ]
  },
  "StreamBufferSettings": {
    "StreamBufferCount": 3,
    "CtrlStreamBufferSizeInMB": 5,
    "StreamBufferSizeInMB": 8
  },
  "ErrorBehavior": {
    "FailOnNoTablesCaptured": false,
    "ApplyErrorUpdatePolicy": "LOG_ERROR",
    "FailOnTransactionConsistencyBreached": false,
    "RecoverableErrorThrottlingMax": 3600,
    "DataErrorEscalationPolicy": "SUSPEND_TABLE",
    "ApplyErrorEscalationCount": 100,
    "RecoverableErrorStopRetryAfterThrottlingMax": false,
    "RecoverableErrorThrottling": true,
    "ApplyErrorFailOnTruncationDdl": false,
    "DataMaskingErrorPolicy": "STOP_TASK",
    "DataTruncationErrorPolicy": "LOG_ERROR",
    "ApplyErrorInsertPolicy": "LOG_ERROR",
    "EventErrorPolicy": "IGNORE",
    "ApplyErrorEscalationPolicy": "LOG_ERROR",
    "RecoverableErrorCount": 15,
    "DataErrorEscalationCount": 50,
    "TableErrorEscalationPolicy": "SUSPEND_TABLE",
    "RecoverableErrorInterval": 10,
    "ApplyErrorDeletePolicy": "IGNORE_RECORD",
    "TableErrorEscalationCount": 5,
    "FullLoadIgnoreConflicts": true,
    "DataErrorPolicy": "LOG_ERROR",
    "TableErrorPolicy": "SUSPEND_TABLE"
  },
  "TTSettings": {
    "TTS3Settings": null,
    "TTRecordSettings": null,
    "EnableTT": false
  },
  "FullLoadSettings": {
    "CommitRate": 10000,
    "StopTaskCachedChangesApplied": false,
    "StopTaskCachedChangesNotApplied": false,
    "MaxFullLoadSubTasks": 8,
    "TransactionConsistencyTimeout": 600,
    "CreatePkAfterFullLoad": false,
    "TargetTablePrepMode": "DO_NOTHING"
  },
  "TargetMetadata": {
    "ParallelApplyBufferSize": 0,
    "ParallelApplyQueuesPerThread": 0,
    "ParallelApplyThreads": 0,
    "TargetSchema": "PAYTEND",
    "InlineLobMaxSize": 0,
    "ParallelLoadQueuesPerThread": 0,
    "SupportLobs": false,
    "LobChunkSize": 0,
    "TaskRecoveryTableEnabled": true,
    "ParallelLoadThreads": 0,
    "LobMaxSize": 32,
    "BatchApplyEnabled": true,
    "FullLobMode": false,
    "LimitedSizeLobMode": false,
    "LoadMaxFileSize": 0,
    "ParallelLoadBufferSize": 0
  },
  "BeforeImageSettings": null,
  "ControlTablesSettings": {
    "historyTimeslotInMinutes": 5,
    "HistoryTimeslotInMinutes": 5,
    "StatusTableEnabled": true,
    "SuspendedTablesTableEnabled": true,
    "HistoryTableEnabled": false,
    "ControlSchema": "",
    "FullLoadExceptionTableEnabled": false
  },
  "LoopbackPreventionSettings": null,
  "CharacterSetSettings": null,
  "FailTaskWhenCleanTaskResourceFailed": false,
  "ChangeProcessingTuning": {
    "StatementCacheSize": 50,
    "CommitTimeout": 1,
    "RecoveryTimeout": -1,
    "BatchApplyPreserveTransaction": true,
    "BatchApplyTimeoutMin": 1,
    "BatchSplitSize": 0,
    "BatchApplyTimeoutMax": 30,
    "MinTransactionSize": 1000,
    "MemoryKeepTime": 60,
    "BatchApplyMemoryLimit": 500,
    "MemoryLimitTotal": 1024
  },
  "ChangeProcessingDdlHandlingPolicy": {
    "HandleSourceTableDropped": true,
    "HandleSourceTableTruncated": true,
    "HandleSourceTableAltered": true
  },
  "PostProcessingRules": null
}
' 

# output
{
    "ReplicationConfig": 
    {
        "ReplicationConfigIdentifier": "climysql2psql",
        "ReplicationConfigArn": "arn:aws:dms:ap-southeast-2:123456789012:replication-config:ABCXXDEFGHIJJXABC4ABC2ABCABCVAB2TNQ3ABC",
        "SourceEndpointArn": "arn:aws:dms:ap-southeast-2:123456789012:endpoint:ABCD4E67FGHIJJKLMNOPQRSTUUVWXY2ZABCDE3F",
        "TargetEndpointArn": "arn:aws:dms:ap-southeast-2:123456789012:endpoint:HG7FED2CB5AZ7YXWVUTSRQPO3M3LKJIHGFED4CBA",
        "ReplicationType": "full-load-and-cdc",
        "ComputeConfig": 
        {
            "MaxCapacityUnits": 4,
            "MultiAZ": false,
            "ReplicationSubnetGroupId": "dmsreplicationsubnetgroup-2b2cdefghijklm7no",
            "VpcSecurityGroupIds": [
                "sg-1123ab4566cd7ef89"
            ]
        },
        "ReplicationSettings": "{\"TargetMetadata\":{\"TargetSchema\":\"\",\"SupportLobs\":true,\"FullLobMode\":false,\"LobChunkSize\":64,\"LimitedSizeLobMode\":true,\"LobMaxSize\":32,\"InlineLobMaxSize\":0,\"LoadMaxFileSize\":0,\"ParallelLoadThreads\":0,\"ParallelLoadBufferSize\":0,\"BatchApplyEnabled\":false,\"TaskRecoveryTableEnabled\":false,\"ParallelLoadQueuesPerThread\":0,\"ParallelApplyThreads\":0,\"ParallelApplyBufferSize\":0,\"ParallelApplyQueuesPerThread\":0},\"FullLoadSettings\":{\"TargetTablePrepMode\":\"DROP_AND_CREATE\",\"CreatePkAfterFullLoad\":false,\"StopTaskCachedChangesApplied\":false,\"StopTaskCachedChangesNotApplied\":false,\"MaxFullLoadSubTasks\":8,\"TransactionConsistencyTimeout\":600,\"CommitRate\":10000},\"Logging\":{\"EnableLogging\":true,\"EnableLogContext\":false,\"LogComponents\":[{\"Id\":\"TRANSFORMATION\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"SOURCE_UNLOAD\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"IO\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"TARGET_LOAD\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"PERFORMANCE\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"SOURCE_CAPTURE\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"SORTER\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"REST_SERVER\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"VALIDATOR_EXT\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"TARGET_APPLY\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"TASK_MANAGER\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"TABLES_MANAGER\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"METADATA_MANAGER\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"FILE_FACTORY\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"COMMON\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"ADDONS\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"DATA_STRUCTURE\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"COMMUNICATION\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"FILE_TRANSFER\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"}],\"CloudWatchLogGroup\":null,\"CloudWatchLogStream\":null},\"ControlTablesSettings\":{\"historyTimeslotInMinutes\":5,\"ControlSchema\":\"\",\"HistoryTimeslotInMinutes\":5,\"HistoryTableEnabled\":false,\"SuspendedTablesTableEnabled\":false,\"StatusTableEnabled\":false,\"FullLoadExceptionTableEnabled\":false},\"StreamBufferSettings\":{\"StreamBufferCount\":3,\"StreamBufferSizeInMB\":8,\"CtrlStreamBufferSizeInMB\":5},\"ChangeProcessingDdlHandlingPolicy\":{\"HandleSourceTableDropped\":true,\"HandleSourceTableTruncated\":true,\"HandleSourceTableAltered\":true},\"ErrorBehavior\":{\"DataErrorPolicy\":\"LOG_ERROR\",\"EventErrorPolicy\":\"IGNORE\",\"DataTruncationErrorPolicy\":\"LOG_ERROR\",\"DataErrorEscalationPolicy\":\"SUSPEND_TABLE\",\"DataErrorEscalationCount\":0,\"TableErrorPolicy\":\"SUSPEND_TABLE\",\"TableErrorEscalationPolicy\":\"STOP_TASK\",\"TableErrorEscalationCount\":0,\"RecoverableErrorCount\":-1,\"RecoverableErrorInterval\":5,\"RecoverableErrorThrottling\":true,\"RecoverableErrorThrottlingMax\":1800,\"RecoverableErrorStopRetryAfterThrottlingMax\":true,\"ApplyErrorDeletePolicy\":\"IGNORE_RECORD\",\"ApplyErrorInsertPolicy\":\"LOG_ERROR\",\"ApplyErrorUpdatePolicy\":\"LOG_ERROR\",\"ApplyErrorEscalationPolicy\":\"LOG_ERROR\",\"ApplyErrorEscalationCount\":0,\"ApplyErrorFailOnTruncationDdl\":false,\"FullLoadIgnoreConflicts\":true,\"FailOnTransactionConsistencyBreached\":false,\"FailOnNoTablesCaptured\":true},\"ChangeProcessingTuning\":{\"BatchApplyPreserveTransaction\":true,\"BatchApplyTimeoutMin\":1,\"BatchApplyTimeoutMax\":30,\"BatchApplyMemoryLimit\":500,\"BatchSplitSize\":0,\"MinTransactionSize\":1000,\"CommitTimeout\":1,\"MemoryLimitTotal\":1024,\"MemoryKeepTime\":60,\"StatementCacheSize\":50},\"PostProcessingRules\":null,\"CharacterSetSettings\":null,\"LoopbackPreventionSettings\":null,\"BeforeImageSettings\":null,\"FailTaskWhenCleanTaskResourceFailed\":false,\"TTSettings\":{\"EnableTT\":false,\"FailTaskOnTTFailure\":false,\"TTS3Settings\":null,\"TTRecordSettings\":null}}",
        "TableMappings": "{\n    \"rules\": [\n        {\n            \"rule-id\": \"783282541\",\n            \"rule-name\": \"783282541\",\n            \"rule-type\": \"selection\",\n            \"rule-action\": \"include\",\n            \"object-locator\": {\n                \"schema-name\": \"mydata\",\n                \"table-name\": \"newtable\"\n            },\n            \"filters\": []\n        },\n        {\n            \"rule-id\": 1152034124,\n            \"rule-name\": \"lkbtwrp3-a00w9q\",\n            \"rule-type\": \"transformation\",\n            \"rule-target\": \"schema\",\n            \"rule-action\": \"rename\",\n            \"object-locator\": {\n                \"schema-name\": \"mydata\"\n            },\n            \"value\": \"public\"\n        }\n    ]\n}",
        "ReplicationConfigCreateTime": "2023-07-31T15:28:56.540000+10:00",
        "ReplicationConfigUpdateTime": "2023-07-31T15:28:56.540000+10:00"
    }
}

# describe the newly created replication config
aws dms describe-replication-configs --query "ReplicationConfigs[?contains(ReplicationConfigIdentifier,'cli')]"

# output
[
    {
        "ReplicationConfigIdentifier": "climysql2psql",
        "ReplicationConfigArn": "arn:aws:dms:ap-southeast-2:123456789012:replication-config:ABCXXDEFGHIJJXABC4ABC2ABCABCVAB2TNQ3ABC",
        "SourceEndpointArn": "arn:aws:dms:ap-southeast-2:123456789012:endpoint:ABCD4E67FGHIJJKLMNOPQRSTUUVWXY2ZABCDE3F",
        "TargetEndpointArn": "arn:aws:dms:ap-southeast-2:123456789012:endpoint:HG7FED2CB5AZ7YXWVUTSRQPO3M3LKJIHGFED4CBA",
        "ReplicationType": "full-load-and-cdc",
        "ComputeConfig": {
            "MaxCapacityUnits": 4,
            "MultiAZ": false,
            "ReplicationSubnetGroupId": "dmsreplicationsubnetgroup-2b2cdefghijklm7no",
            "VpcSecurityGroupIds": [
                "sg-1123ab4566cd7ef89"
            ]
        },
        "ReplicationSettings": "{\"TargetMetadata\":{\"TargetSchema\":\"\",\"SupportLobs\":true,\"FullLobMode\":false,\"LobChunkSize\":64,\"LimitedSizeLobMode\":true,\"LobMaxSize\":32,\"InlineLobMaxSize\":0,\"LoadMaxFileSize\":0,\"ParallelLoadThreads\":0,\"ParallelLoadBufferSize\":0,\"BatchApplyEnabled\":false,\"TaskRecoveryTableEnabled\":false,\"ParallelLoadQueuesPerThread\":0,\"ParallelApplyThreads\":0,\"ParallelApplyBufferSize\":0,\"ParallelApplyQueuesPerThread\":0},\"FullLoadSettings\":{\"TargetTablePrepMode\":\"DROP_AND_CREATE\",\"CreatePkAfterFullLoad\":false,\"StopTaskCachedChangesApplied\":false,\"StopTaskCachedChangesNotApplied\":false,\"MaxFullLoadSubTasks\":8,\"TransactionConsistencyTimeout\":600,\"CommitRate\":10000},\"Logging\":{\"EnableLogging\":true,\"EnableLogContext\":false,\"LogComponents\":[{\"Id\":\"TRANSFORMATION\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"SOURCE_UNLOAD\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"IO\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"TARGET_LOAD\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"PERFORMANCE\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"SOURCE_CAPTURE\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"SORTER\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"REST_SERVER\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"VALIDATOR_EXT\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"TARGET_APPLY\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"TASK_MANAGER\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"TABLES_MANAGER\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"METADATA_MANAGER\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"FILE_FACTORY\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"COMMON\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"ADDONS\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"DATA_STRUCTURE\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"COMMUNICATION\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"},{\"Id\":\"FILE_TRANSFER\",\"Severity\":\"LOGGER_SEVERITY_DEFAULT\"}],\"CloudWatchLogGroup\":null,\"CloudWatchLogStream\":null},\"ControlTablesSettings\":{\"historyTimeslotInMinutes\":5,\"ControlSchema\":\"\",\"HistoryTimeslotInMinutes\":5,\"HistoryTableEnabled\":false,\"SuspendedTablesTableEnabled\":false,\"StatusTableEnabled\":false,\"FullLoadExceptionTableEnabled\":false},\"StreamBufferSettings\":{\"StreamBufferCount\":3,\"StreamBufferSizeInMB\":8,\"CtrlStreamBufferSizeInMB\":5},\"ChangeProcessingDdlHandlingPolicy\":{\"HandleSourceTableDropped\":true,\"HandleSourceTableTruncated\":true,\"HandleSourceTableAltered\":true},\"ErrorBehavior\":{\"DataErrorPolicy\":\"LOG_ERROR\",\"EventErrorPolicy\":\"IGNORE\",\"DataTruncationErrorPolicy\":\"LOG_ERROR\",\"DataErrorEscalationPolicy\":\"SUSPEND_TABLE\",\"DataErrorEscalationCount\":0,\"TableErrorPolicy\":\"SUSPEND_TABLE\",\"TableErrorEscalationPolicy\":\"STOP_TASK\",\"TableErrorEscalationCount\":0,\"RecoverableErrorCount\":-1,\"RecoverableErrorInterval\":5,\"RecoverableErrorThrottling\":true,\"RecoverableErrorThrottlingMax\":1800,\"RecoverableErrorStopRetryAfterThrottlingMax\":true,\"ApplyErrorDeletePolicy\":\"IGNORE_RECORD\",\"ApplyErrorInsertPolicy\":\"LOG_ERROR\",\"ApplyErrorUpdatePolicy\":\"LOG_ERROR\",\"ApplyErrorEscalationPolicy\":\"LOG_ERROR\",\"ApplyErrorEscalationCount\":0,\"ApplyErrorFailOnTruncationDdl\":false,\"FullLoadIgnoreConflicts\":true,\"FailOnTransactionConsistencyBreached\":false,\"FailOnNoTablesCaptured\":true},\"ChangeProcessingTuning\":{\"BatchApplyPreserveTransaction\":true,\"BatchApplyTimeoutMin\":1,\"BatchApplyTimeoutMax\":30,\"BatchApplyMemoryLimit\":500,\"BatchSplitSize\":0,\"MinTransactionSize\":1000,\"CommitTimeout\":1,\"MemoryLimitTotal\":1024,\"MemoryKeepTime\":60,\"StatementCacheSize\":50},\"PostProcessingRules\":null,\"CharacterSetSettings\":null,\"LoopbackPreventionSettings\":null,\"BeforeImageSettings\":null,\"FailTaskWhenCleanTaskResourceFailed\":false,\"TTSettings\":{\"EnableTT\":false,\"FailTaskOnTTFailure\":false,\"TTS3Settings\":null,\"TTRecordSettings\":null}}",
        "TableMappings": "{\n    \"rules\": [\n        {\n            \"rule-id\": \"783282541\",\n            \"rule-name\": \"783282541\",\n            \"rule-type\": \"selection\",\n            \"rule-action\": \"include\",\n            \"object-locator\": {\n                \"schema-name\": \"mydata\",\n                \"table-name\": \"newtable\"\n            },\n            \"filters\": []\n        },\n        {\n            \"rule-id\": 1152034124,\n            \"rule-name\": \"lkbtwrp3-a00w9q\",\n            \"rule-type\": \"transformation\",\n            \"rule-target\": \"schema\",\n            \"rule-action\": \"rename\",\n            \"object-locator\": {\n                \"schema-name\": \"mydata\"\n            },\n            \"value\": \"public\"\n        }\n    ]\n}",
        "ReplicationConfigCreateTime": "2023-07-31T15:28:56.540000+10:00"
    }
] 