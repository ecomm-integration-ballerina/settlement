FROM ballerina/ballerina:0.982.0
LABEL maintainer="rajkumarr@wso2.com"

COPY target/settlement-outbound-sap-processor.balx /home/ballerina
COPY settlement-outbound-sap-processor/conf/ballerina.conf /home/ballerina

EXPOSE  8280

CMD ballerina run settlement-outbound-sap-processor.balx