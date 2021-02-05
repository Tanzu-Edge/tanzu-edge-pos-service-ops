APPS_BASE=/home/ubuntu/apps/tanzu-edge-pos
RABBIT_OPERATOR_MANIFEST=/home/ubuntu/apps/rabbit-mq/release-artifacts/manifests/cluster-operator.yml
for i in {2..4}; do
#for j in {1..20}; do
tkg get credentials edge-workload-${i} --export-file=site-${i}-kubeconfig
export KUBECONFIG=$APPS_BASE/site-${i}-kubeconfig

EDGE_RMQ_USERNAME=$(kubectl -n edge-data-services get secret edge-pos-messaging-default-user -o jsonpath='{.data.username}' | base64 --decode)
EDGE_RMQ_PSWD=$(kubectl -n edge-data-services get secret edge-pos-messaging-default-user -o jsonpath='{.data.password}' | base64 --decode)

NODE_IP=$(kubectl get nodes --selector='!node-role.kubernetes.io/master' --namespace edge-data-services -o jsonpath="{.items[0].status.addresses[1].address}")
NODE_PORT_AMQP=$(kubectl get --namespace edge-data-services -o jsonpath="{.spec.ports[?(@.port==5672)].nodePort}" services edge-pos-messaging)

export KUBECONFIG=$APPS_BASE/site-0-kubeconfig
kubectl -n dc-data-services exec -it dc-pos-messaging-server-0 -- \
    rabbitmqctl set_parameter federation-upstream store-${i} '{"uri":"amqp://'${EDGE_RMQ_USERNAME}':'${EDGE_RMQ_PSWD}'@'${NODE_IP}':'${NODE_PORT_AMQP}'"}'
kubectl -n dc-data-services  exec -it dc-pos-messaging-server-0 -- \
    rabbitmqctl set_policy --apply-to exchanges federate-pos "^pos" '{"federation-upstream-set":"all"}'

done
