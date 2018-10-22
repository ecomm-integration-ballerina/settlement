FROM ballerina/ballerina:0.982.0
LABEL maintainer="rajkumarr@wso2.com"

COPY target/settlement-inbound-processor.balx /home/ballerina
COPY settlement-inbound-processor/conf/ballerina.conf /home/ballerina

EXPOSE  8280

CMD ballerina run settlement-inbound-processor.balx