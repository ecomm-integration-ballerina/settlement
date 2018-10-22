ballerina build settlement-outbound-dispatcher
docker build -t rajkumar/settlement-outbound-dispatcher:0.1.0 -f settlement-outbound-dispatcher/docker/Dockerfile .
docker push rajkumar/settlement-outbound-dispatcher:0.1.0
kubectl delete -f settlement-outbound-dispatcher/kubernetes/settlement_outbound_dispatcher_deployment.yaml
kubectl apply -f settlement-outbound-dispatcher/kubernetes/settlement_outbound_dispatcher_deployment.yaml