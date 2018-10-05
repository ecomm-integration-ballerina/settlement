import ballerina/io;
import ballerina/http;
import ballerina/config;
import ballerina/mb;
import raj/settlement.model as model;

endpoint mb:SimpleQueueSender settlementInboundQueue {
    host: config:getAsString("settlement.mb.host"),
    port: config:getAsInt("settlement.mb.port"),
    queueName: config:getAsString("settlement.mb.queueName")
};

public function addSettlement (http:Request req, model:Settlement settlement) returns http:Response {

    http:Response res = new;
    string referenceId = settlement.referenceId;
    string settlementString = model:settlementToString(settlement);

    log:printInfo("Received settlement " + referenceId + ". Payload: \n" + settlementString);
    
    match (settlementInboundQueue.createTextMessage(settlementString)) {
        
        error e => {
            log:printError("Error occurred while creating message", err = e);
        }
        mb:Message msg => {

            log:printInfo("Inserting settlement " + referenceId + " into settlementInboundQueue");
            settlementInboundQueue->send(msg) but {
                error e => log:printError("Error occurred while sending message to settlementInboundQueue", err = e)
            };
        }
    }
    
    return res;
}