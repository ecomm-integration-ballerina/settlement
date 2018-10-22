FROM ballerina/ballerina:0.982.0
LABEL maintainer="rajkumarr@wso2.com"

COPY target/settlement-inbound-dispatcher.balx /home/ballerina
COPY settlement-inbound-dispatcher/conf/ballerina.conf /home/ballerina

CMD ballerina run settlement-inbound-dispatcher.balx
