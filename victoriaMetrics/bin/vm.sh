VM_HOME='/home/sujian02/vm_tsdb/victoriaMetrics'
MEM_LIMIT='12800MB'    #内存使用限制
VMSOTRAGE_PORT='8482'  #vmstorage监听端口
VMSOTRAGE_INSERT_PORT='8400'  #vmstorage对vminsert提供服务的监听端口
VMSOTRAGE_SELECT_PORT='8401'  #vmstorage对vmselect提供服务的监听端口
VMINSERT_PORT='8480'  #vminsert监听端口
VMSELECT_PORT='8481'  #vmselect监听端口
VMAGENT_PORT='8429'    #vmagent监听端口
REPLICATION_COUNT='2'   #副本数
SELECT_STORAGE_NODE_LIST=''
INSERT_STORAGE_NODE_LIST=''
NODE_LIST='7.58.117.67,7.58.117.68,7.58.117.69'
for NODE_IP in $(echo ${NODE_LIST} | awk '{split($0,arr,",");for(i in arr) print arr[i]}')
do
    INSERT_STORAGE_NODE_LIST="${INSERT_STORAGE_NODE_LIST}\"${NODE_IP}:${VMSOTRAGE_INSERT_PORT}\","
    SELECT_STORAGE_NODE_LIST="${SELECT_STORAGE_NODE_LIST}\"${NODE_IP}:${VMSOTRAGE_SELECT_PORT}\","
done
# 创建程序目录
mkdir -p ${VM_HOME}/{bin,logs,data,config}
 
 
# 启动vmstorage服务（所有节点运行）
nohup ${VM_HOME}/bin/vmstorage-prod -retentionPeriod=365d \
    -storageDataPath=${VM_HOME}/data/vmstorage \
    -memory.allowedBytes=${MEM_LIMIT} \
    -httpListenAddr=":${VMSOTRAGE_PORT}" \
    -vminsertAddr=":${VMSOTRAGE_INSERT_PORT}" \
    -vmselectAddr=":${VMSOTRAGE_SELECT_PORT}" \
    -dedup.minScrapeInterval=30s \
     > ${VM_HOME}/logs/vmstorage.log 2>&1 &

# 启动vminsert服务（所有节点运行）
nohup ${VM_HOME}/bin/vminsert-prod -replicationFactor=2 \
    -storageNode=${INSERT_STORAGE_NODE_LIST} \
    -memory.allowedBytes=${MEM_LIMIT} \
    -httpListenAddr=":${VMINSERT_PORT}" \
    > ${VM_HOME}/logs/vminsert.log 2>&1 &

# 启动vmselect服务（所有节点运行）
nohup ${VM_HOME}/bin/vmselect-prod -dedup.minScrapeInterval=30s \
    -replicationFactor=${REPLICATION_COUNT} \
    -storageNode=${SELECT_STORAGE_NODE_LIST} \
    -memory.allowedBytes=${MEM_LIMIT} \
    -httpListenAddr=":${VMSELECT_PORT}" \
    > ${VM_HOME}/logs/vmselect.log 2>&1 &

# 启动vmagent服务（所有节点运行）
VM_INSERT_URL="http://localhost:${VMINSERT_PORT}"
ACCOUNT_ID='6666'   #租户ID
MEMBER_NUM=0    #每个节点不一样，取值范围0~(membersCount-1)
nohup ${VM_HOME}/bin/vmagent-prod -promscrape.cluster.membersCount=3 \
    -promscrape.cluster.memberNum=${MEMBER_NUM} \
    -promscrape.cluster.replicationFactor=${REPLICATION_COUNT} \
    -promscrape.suppressScrapeErrors \
    -remoteWrite.tmpDataPath=${VM_HOME}/data/vmagent \
    -remoteWrite.maxDiskUsagePerURL=1GB \
    -memory.allowedBytes=${MEM_LIMIT} \
    -httpListenAddr=":${VMAGENT_PORT}" \
    -promscrape.config=${VM_HOME}/config/prometheus.yml \
    -remoteWrite.url=${VM_INSERT_URL}/insert/${ACCOUNT_ID}/prometheus/api/v1/write \
    > ${VM_HOME}/logs/vmagent.log 2>&1 &
