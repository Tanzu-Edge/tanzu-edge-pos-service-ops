APPS_BASE=`pwd`
for i in {1..4}; do
#for j in {1..20}; do
export KUBECONFIG=$APPS_BASE/site-${i}-kubeconfig

kubectl delete namespace edge-data-services
kubectl delete namespace edge-store
kubectl delete namespace rabbitmq-system
done
