ballerina build settlement-inbound-dispatcher
docker build -t rajkumar/settlement-inbound-dispatcher:0.1.0 -f settlement-inbound-dispatcher/docker/Dockerfile .
docker push rajkumar/settlement-inbound-dispatcher:0.1.0
kubectl delete -f settlement-inbound-dispatcher/kubernetes/settlement_inbound_dispatcher_deployment.yaml
kubectl apply -f settlement-inbound-dispatcher/kubernetes/settlement_inbound_dispatcher_deployment.yaml