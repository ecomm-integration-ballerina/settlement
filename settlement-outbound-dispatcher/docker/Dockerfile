FROM ballerina/ballerina:0.982.0
LABEL maintainer="rajkumarr@wso2.com"

COPY target/settlement-outbound-dispatcher.balx /home/ballerina
COPY settlement-outbound-dispatcher/conf/ballerina.conf /home/ballerina

EXPOSE  8280

CMD ballerina run settlement-outbound-dispatcher.balx