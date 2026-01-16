source ~/.bash_profile
cd ~
sudo ./git_checkout_branch.sh /opt/business_metrics_collector/ felixzhang-mgr/business_metrics_collector main
cd /opt/business_metrics_collector/
export ORACLE_USERNAME=PAYTEND_BI
export ORACLE_PASSWORD=PAYTEND_8!
export ORACLE_HOST=172.31.70.249
export ORACLE_PORT=1521
export ORACLE_SERVICE=PAYTEND
sudo -E ./oracle_collector_ctl.sh restart

tail -f /opt/business_metrics_collector/oracle_collector.log