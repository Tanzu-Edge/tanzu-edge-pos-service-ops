APPS_BASE=`pwd`
RABBIT_OPERATOR_MANIFEST=/home/ubuntu/apps/rabbit-mq/release-artifacts/manifests/cluster-operator.yml
for i in {1..4}; do
#for j in {1..20}; do
tkg get credentials edge-workload-${i} --export-file=site-${i}-kubeconfig
export KUBECONFIG=$APPS_BASE/site-${i}-kubeconfig

kubectl create namespace edge-data-services
kubectl create namespace edge-store
kubectl create -f $RABBIT_OPERATOR_MANIFEST
echo "waiting 60s for rabbit operator to start..."
sleep 60
kubectl create -f edge-pos-messaging.yaml -n edge-data-services

EDGE_RMQ_USERNAME=$(kubectl -n edge-data-services get secret edge-pos-messaging-default-user -o jsonpath='{.data.username}' | base64 --decode)
EDGE_RMQ_PSWD=$(kubectl -n edge-data-services get secret edge-pos-messaging-default-user -o jsonpath='{.data.password}' | base64 --decode)
ytt -f $APPS_BASE/pos/k8s/ -v storeId=store-${i} -v posUri=pos.site-${i}.storm.pvd.pez.pivotal.io | kubectl -n edge-store create -f -
ytt -f $APPS_BASE/pos-data-service/k8s/sender -v storeId=store-${i} -v rabbitmq_password=${EDGE_RMQ_PSWD} -v rabbitmq_username=${EDGE_RMQ_USERNAME} | kubectl -n edge-store create -f -

NODE_IP=$(kubectl get nodes --selector='!node-role.kubernetes.io/master' --namespace edge-data-services -o jsonpath="{.items[0].status.addresses[1].address}")
NODE_PORT_AMQP=$(kubectl get --namespace edge-data-services -o jsonpath="{.spec.ports[?(@.port==5672)].nodePort}" services edge-pos-messaging)

export KUBECONFIG=$APPS_BASE/site-0-kubeconfig
kubectl -n dc-data-services exec -it dc-pos-messaging-server-0 -- \
    rabbitmqctl set_parameter federation-upstream store-${i} '{"uri":"amqp://user:'${EDGE_RMQ_PSWD}'@'${NODE_IP}':'${NODE_PORT_AMQP}'"}'
kubectl -n dc-data-services  exec -it dc-pos-messaging-server-0 -- \
    rabbitmqctl set_policy --apply-to exchanges federate-pos "^pos" '{"federation-upstream-set":"all"}'

done
