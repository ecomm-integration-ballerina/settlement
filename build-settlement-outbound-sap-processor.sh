ballerina build settlement-outbound-sap-processor
docker build -t rajkumar/settlement-outbound-sap-processor:0.1.0 -f settlement-outbound-sap-processor/docker/Dockerfile .
docker push rajkumar/settlement-outbound-sap-processor:0.1.0
kubectl delete -f settlement-outbound-sap-processor/kubernetes/settlement_outbound_sap_processor_deployment.yaml
kubectl apply -f settlement-outbound-sap-processor/kubernetes/settlement_outbound_sap_processor_deployment.yaml