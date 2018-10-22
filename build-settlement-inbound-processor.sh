ballerina build settlement-inbound-processor
docker build -t rajkumar/settlement-inbound-processor:0.1.0 -f settlement-inbound-processor/docker/Dockerfile .
docker push rajkumar/settlement-inbound-processor:0.1.0
kubectl delete -f settlement-inbound-processor/kubernetes/settlement_inbound_processor_deployment.yaml
kubectl apply -f settlement-inbound-processor/kubernetes/settlement_inbound_processor_deployment.yaml