import ballerina/io;
import ballerina/config;
import ballerina/log;
import ballerina/mb;
import ballerina/http;

endpoint http:Client settlementDataEndpoint {
    url: config:getAsString("settlement.data.service.url")
};

endpoint mb:SimpleQueueReceiver settlementInboundQueue {
    host: config:getAsString("settlement.mb.host"),
    port: config:getAsInt("settlement.mb.port"),
    queueName: config:getAsString("settlement.mb.queueName")
};

service<mb:Consumer> settlementInboundQueueReceiver bind settlementInboundQueue {

    onMessage(endpoint consumer, mb:Message message) {

        json settlementJson;
        match message.getTextMessageContent() {

            string settlementString => {
                io:StringReader sr = new(settlementString);
                settlementJson = check sr.readJson();
                string orderNo = check <string> settlementJson.referenceId;

                log:printInfo("Received settlemen " + orderNo + " from settlementInboundQueue");

                handleSettlement(settlementJson);
            }

            error e => {
                log:printError("Error occurred while reading message from settlementInboundQueue", err = e);
            }
        }
    }
}

function handleSettlement (json settlement) {
    
    json payload = {
        "orderNo": settlement.referenceId,
        "request": settlement,
        "processFlag": "N",
        "retryCount": 0,
        "errorMessage": "None"
    };

    http:Request req = new;
    req.setJsonPayload(untaint payload);
    var response = settlementDataEndpoint->post("/", req);

    match response {
        http:Response resp => {
            match resp.getJsonPayload() {
                json j => {
                    log:printInfo("Response from settlementDataEndpoint : " + j.toString());
                }
                error err => {
                    log:printError("Response from settlementDataEndpoint is not a json : " + err.message, err = err);
                }
            }
        }
        error err => {
            log:printError("Error while calling settlementDataEndpoint : " + err.message, err = err);
        }
    }    
}