APPS_BASE=`pwd`
RABBIT_OPERATOR_MANIFEST=/home/ubuntu/apps/rabbit-mq/release-artifacts/manifests/cluster-operator.yml
#for j in {1..20}; do
i=0 
tkg get credentials edge-workload-${i} --export-file=site-${i}-kubeconfig
export KUBECONFIG=$APPS_BASE/site-${i}-kubeconfig

kubectl create namespace dc-data-services
kubectl create namespace dc-store
kubectl create -f $RABBIT_OPERATOR_MANIFEST
echo "waiting 60s for rabbit operator to start..."
sleep 60
kubectl -n dc-data-services create configmap definitions --from-file='def.json=../k8s/sender/rabbit-definitions.json'
kubectl create -f dc-pos-messaging.yaml -n dc-data-services

EDGE_RMQ_USERNAME=$(kubectl -n dc-data-services get secret dc-pos-messaging-default-user -o jsonpath='{.data.username}' | base64 --decode)
EDGE_RMQ_PSWD=$(kubectl -n dc-data-services get secret dc-pos-messaging-default-user -o jsonpath='{.data.password}' | base64 --decode)
DC_SQL_USERNAME=$(kubectl -n dc-data-services get secret dc-pos-sql-db-secret -o jsonpath='{.data.username}' | base64 --decode)
DC_SQL_PSWD=$(kubectl -n dc-data-services get secret dc-pos-sql-db-secret -o jsonpath='{.data.password}' | base64 --decode)
ytt -f $APPS_BASE/pos-data-service/k8s/receiver -v storeId=store-${i} -v postgresql_password=${DC_SQL_PSWD} -v postgresql_username=${DC_SQL_USERNAME} -v rabbitmq_password=${EDGE_RMQ_PSWD} -v rabbitmq_username=${EDGE_RMQ_USERNAME} | kubectl -n dc-store create -f -

