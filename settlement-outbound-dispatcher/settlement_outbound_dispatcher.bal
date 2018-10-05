import ballerina/log;
import ballerina/http;
import ballerina/config;
import ballerina/task;
import ballerina/runtime;
import ballerina/io;
import ballerina/mb;
import raj/settlement.model as model;

endpoint mb:SimpleTopicPublisher settlementOutboundPublisher {
    host: config:getAsString("settlement.mb.host"),
    port: config:getAsInt("settlement.mb.port"),
    topicPattern: config:getAsString("settlement.mb.topicName")
};

endpoint http:Client settlementDataServiceEndpoint {
    url: config:getAsString("settlement.data.service.url")
};

int count;
task:Timer? timer;
int interval = config:getAsInt("settlement.outbound.dispatcher.task.interval");
int delay = config:getAsInt("settlement.outbound.dispatcher.task.delay");
int maxRetryCount = config:getAsInt("settlement.outbound.dispatcher.task.maxRetryCount");
int maxRecords = config:getAsInt("settlement.outbound.dispatcher.task.maxRecords");

function main(string... args) {

    (function() returns error?) onTriggerFunction = doSettlementOutboundDispatcherETL;

    function(error) onErrorFunction = handleError;

    log:printInfo("Starting Settlement Outbound Dispatcher ETL");

    timer = new task:Timer(onTriggerFunction, onErrorFunction,
        interval, delay = delay);

    timer.start();
    runtime:sleep(20000000);
}

function doSettlementOutboundDispatcherETL() returns  error? {

    log:printInfo("Calling settlementDataServiceEndpoint to fetch settlements");

    var response = settlementDataServiceEndpoint->get("?maxRecords=" + maxRecords
            + "&maxRetryCount=" + maxRetryCount + "&processFlag=N,E");

    match response {
        http:Response resp => {
            match resp.getJsonPayload() {
                json jsonSettlementArray => { 
                    model:SettlementDAO[] settlements = check <model:SettlementDAO[]> jsonSettlementArray;
                    // terminate the flow if no settlements found
                    if (lengthof settlements == 0) {
                        return;
                    }
                    // update process flag to P in DB so that next ETL won't fetch these again
                    boolean success = batchUpdateProcessFlagsToP(settlements);
                    // send settlements to settlementOutboundTopic
                    if (success) {
                        publishSettlementsToTopic(settlements);
                    }
                }
                error err => {
                    log:printError("Response from settlementDataServiceEndpoint is not a json : " + 
                                    err.message, err = err);
                    throw err;
                }
            }
        }
        error err => {
            log:printError("Error while calling settlementDataServiceEndpoint : " + 
                            err.message, err = err);
            throw err;
        }
    }

    return ();
}

function publishSettlementsToTopic (model:SettlementDAO[] settlements) {

    foreach settlement in settlements {

        int tid = settlement.transactionId;
        string orderNo = settlement.orderNo;
        int retryCount = settlement.retryCount;
       
        json jsonPayload = check <json> settlement;

        match (settlementOutboundPublisher.createTextMessage(jsonPayload.toString())) {
            
            error e => {
                log:printError("Error occurred while creating settlement topic message for tid: " + tid 
                                    + ", order : " + orderNo, err = e);
            }

            mb:Message msg => {

                log:printInfo("Publishing settlement tid: " + tid + ", order : " + orderNo 
                                + " to " + config:getAsString("settlement.mb.topicName") + " topic"
                                + ". Payload:\n" + jsonPayload.toString());

                settlementOutboundPublisher->send(msg) but {
                    error e => log:printError("Error occurred while sending settlement message to " 
                                    + config:getAsString("settlement.mb.topicName") + " topic for tid: " 
                                    + tid + ", order : " + orderNo, err = e)
                };
            }
        }
    }
}

function handleError(error e) {
    log:printError("Error in Settlement Outbound Dispatcher ETL", err = e);
}

function batchUpdateProcessFlagsToP (model:SettlementDAO[] settlements) returns boolean{

    json batchUpdateProcessFlagsPayload;
    foreach i, settlement in settlements {
        json updateProcessFlagPayload = {
            "transactionId": settlement.transactionId,
            "retryCount": settlement.retryCount,
            "processFlag": "P"           
        };
        batchUpdateProcessFlagsPayload.settlements[i] = updateProcessFlagPayload;
    }

    http:Request req = new;
    req.setJsonPayload(untaint batchUpdateProcessFlagsPayload);

    var response = settlementDataServiceEndpoint->put("/process-flag/batch/", req);

    boolean success;
    match response {
        http:Response resp => {
            if (resp.statusCode == 202) {
                success = true;
            }
        }
        error err => {
            log:printError("Error while calling settlementDataServiceEndpoint.batchUpdateProcessFlags", err = err);
        }
    }

    return success;
}

function updateProcessFlag(int tid, int retryCount, string processFlag, string errorMessage) {

    json updateSettlement = {
        "transactionId": tid,
        "processFlag": processFlag,
        "retryCount": retryCount,
        "errorMessage": errorMessage
    };

    http:Request req = new;
    req.setJsonPayload(untaint updateSettlement);

    var response = settlementDataServiceEndpoint->put("/process-flag/", req);

    match response {
        http:Response resp => {
            int httpCode = resp.statusCode;
            if (httpCode == 202) {
                if (processFlag == "E" && retryCount > maxRetryCount) {
                    notifyOperation();
                }
            }
        }
        error err => {
            log:printError("Error while calling settlementDataServiceEndpoint", err = err);
        }
    }
}

function notifyOperation()  {
    // sending email alerts
    log:printInfo("Notifying operations");
}
