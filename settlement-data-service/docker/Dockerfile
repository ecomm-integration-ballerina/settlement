FROM ballerina/ballerina:0.982.0
LABEL maintainer="rajkumarr@wso2.com"

COPY target/settlement-data-service.balx /home/ballerina
COPY settlement-data-service/conf/ballerina.conf /home/ballerina

COPY settlement-data-service/dependencies/packages/dependencies/* /ballerina/runtime/bre/lib/

EXPOSE  8280
EXPOSE  9797

CMD ballerina run settlement-data-service.balx