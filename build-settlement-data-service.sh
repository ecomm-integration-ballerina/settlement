ballerina build settlement-data-service
docker build -t rajkumar/settlement-data-service:0.1.0 -f settlement-data-service/docker/Dockerfile .
docker push rajkumar/settlement-data-service:0.1.0
kubectl delete -f settlement-data-service/kubernetes/settlement_data_service_deployment.yaml
kubectl apply -f settlement-data-service/kubernetes/settlement_data_service_deployment.yaml