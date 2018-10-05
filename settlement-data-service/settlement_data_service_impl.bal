import ballerina/io;
import ballerina/http;
import ballerina/config;
import ballerina/log;
import ballerina/sql;
import ballerina/mime;
import raj/settlement.model as model;

type settlementBatchType string|int|float;

endpoint mysql:Client settlementDB {
    host: config:getAsString("settlement.db.host"),
    port: config:getAsInt("settlement.db.port"),
    name: config:getAsString("settlement.db.name"),
    username: config:getAsString("settlement.db.username"),
    password: config:getAsString("settlement.db.password"),
    poolOptions: { maximumPoolSize: 5 },
    dbOptions: { useSSL: false, serverTimezone:"UTC" }
};

public function addSettlement (http:Request req, model:SettlementDAO settlement) returns http:Response {

    string sqlString = "INSERT INTO settlement(ORDER_NO,REQUEST,PROCESS_FLAG,
        RETRY_COUNT,ERROR_MESSAGE) VALUES (?,?,?,?,?)";

    log:printInfo("Calling settlementDB->insert for order : " + settlement.orderNo);

    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {                              
        
        string base64Request = check mime:base64EncodeString(settlement.request.toString());
        var ret = settlementDB->update(sqlString, settlement.orderNo, base64Request, 
            settlement.processFlag, settlement.retryCount, settlement.errorMessage);

        match ret {
            int insertedRows => {
                if (insertedRows < 1) {
                    log:printError("Calling settlementDB->insert for order : " + settlement.orderNo 
                        + " failed", err = ());
                    isSuccessful = false;
                    abort;
                } else {
                    log:printInfo("Calling settlementDB->insert for order : " + settlement.orderNo + " succeeded");
                    isSuccessful = true;
                }
            }
            error err => {
                log:printError("Calling settlementDB->insert for order : " + settlement.orderNo 
                    + " failed", err = err);
                retry;
            }
        }        
    }  

    json resJson;
    int statusCode;
    if (isSuccessful) {
        statusCode = http:OK_200;
        resJson = { "Status": "Settlement is inserted to the staging database for order : " 
                    + settlement.orderNo };
    } else {
        statusCode = http:INTERNAL_SERVER_ERROR_500;
        resJson = { "Status": "Failed to insert settlement to the staging database for order : " 
                    + settlement.orderNo };
    }
    
    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;
}

public function getSettlements (http:Request req) returns http:Response {

    int retryCount = config:getAsInt("settlement.data.service.default.retryCount");
    int resultsLimit = config:getAsInt("settlement.data.service.default.resultsLimit");
    string processFlag = config:getAsString("settlement.data.service.default.processFlag");

    map<string> params = req.getQueryParams();

    if (params.hasKey("processFlag")) {
        processFlag = params.processFlag;
    }

    if (params.hasKey("maxRetryCount")) {
        match <int> params.maxRetryCount {
            int n => {
                retryCount = n;
            }
            error err => {
                throw err;
            }
        }
    }

    if (params.hasKey("maxRecords")) {
        match <int> params.maxRecords {
            int n => {
                resultsLimit = n;
            }
            error err => {
                throw err;
            }
        }
    }

    string sqlString = "select * from settlement where PROCESS_FLAG in ( ? ) 
        and RETRY_COUNT <= ? order by TRANSACTION_ID asc limit ?";

    string[] processFlagArray = processFlag.split(",");
    sql:Parameter processFlagPara = { sqlType: sql:TYPE_VARCHAR, value: processFlagArray };

    var ret = settlementDB->select(sqlString, model:SettlementDAO, loadToMemory = true, processFlagPara, retryCount, resultsLimit);

    http:Response resp = new;
    json[] jsonReturnValue;
    match ret {
        table<model:SettlementDAO> tableSettlementDAO => {
            foreach settlement in tableSettlementDAO {
                io:StringReader sr = new(check mime:base64DecodeString(settlement.request.toString()));
                json requestJson = check sr.readJson();
                settlement.request = requestJson;
                jsonReturnValue[lengthof jsonReturnValue] = check <json> settlement;
            }

            resp.setJsonPayload(untaint jsonReturnValue);
            resp.statusCode = http:OK_200;
        }
        error err => {
            json respPayload = { "Status": "Internal Server Error", "Error": err.message };
            resp.setJsonPayload(untaint respPayload);
            resp.statusCode = http:INTERNAL_SERVER_ERROR_500;
        }
    }

    return resp;
}

public function updateProcessFlag (http:Request req, model:SettlementDAO settlement)
                    returns http:Response {

    log:printInfo("Calling settlementDB->updateProcessFlag for tid : " + settlement.transactionId);

    string sqlString = "UPDATE settlement SET PROCESS_FLAG = ?, RETRY_COUNT = ?, ERROR_MESSAGE = ?, 
                            LAST_UPDATED_TIME = CURRENT_TIMESTAMP where TRANSACTION_ID = ?";

    json resJson;
    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {                              

        var ret = settlementDB->update(sqlString, settlement.processFlag, settlement.retryCount, 
                                    settlement.errorMessage, settlement.transactionId);

        match ret {
            int updatedRows => {
                if (updatedRows < 1) {
                    log:printError("Calling settlementDB->updateProcessFlag for tid : " + settlement.transactionId + 
                                " failed", err = ());
                    isSuccessful = false;
                    abort;
                } else {
                    log:printInfo("Calling settlementDB->updateProcessFlag for tid : " + settlement.transactionId + 
                         " succeeded");
                    isSuccessful = true;
                }
            }
            error err => {
                log:printError("Calling settlementDB->updateProcessFlag for tid : " + settlement.transactionId +
                    " failed", err = err);
                isSuccessful = false;
                retry;
            }
        } 

    }     

    int statusCode;
    if (isSuccessful) {
        resJson = { "Status": "ProcessFlag is updated for tid  : " + settlement.transactionId };
        statusCode = http:ACCEPTED_202;
    } else {
        resJson = { "Status": "Failed to update ProcessFlag for settlement : " + settlement.transactionId };
        statusCode = http:INTERNAL_SERVER_ERROR_500;
    }

    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;
}

public function batchUpdateProcessFlag (http:Request req, model:SettlementsDAO settlements)
                    returns http:Response {

    settlementBatchType[][] settlementBatches;
    foreach i, settlement in settlements.settlements {
        settlementBatchType[] ref = [settlement.processFlag, settlement.retryCount, 
                                        settlement.errorMessage, settlement.transactionId];
        settlementBatches[i] = ref;
    }
    
    string sqlString = "UPDATE settlement SET PROCESS_FLAG = ?, RETRY_COUNT = ?, ERROR_MESSAGE = ?, 
                            LAST_UPDATED_TIME = CURRENT_TIMESTAMP where TRANSACTION_ID = ?";

    log:printInfo("Calling settlementDB->batchUpdateProcessFlag");
    
    json resJson;
    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {                              

        var retBatch = settlementDB->batchUpdate(sqlString, ... settlementBatches);
        match retBatch {
            int[] counts => {
                foreach count in counts {
                    if (count < 1) {
                        log:printError("Calling settlementDB->batchUpdateProcessFlag failed", err = ());
                        isSuccessful = false;
                        abort;
                    } else {
                        log:printInfo("Calling settlementDB->batchUpdateProcessFlag succeeded");
                        isSuccessful = true;
                    }
                }
            }
            error err => {
                log:printError("Calling settlementDB->batchUpdateProcessFlag failed", err = err);
                retry;
            }
        }      
    }     

    int statusCode;
    if (isSuccessful) {
        resJson = { "Status": "ProcessFlags updated"};
        statusCode = http:ACCEPTED_202;
    } else {
        resJson = { "Status": "ProcessFlags not updated" };
        statusCode = http:INTERNAL_SERVER_ERROR_500;
    }

    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;
}

function onCommitFunction(string transactionId) {
    log:printInfo("Transaction: " + transactionId + " committed");
}

function onAbortFunction(string transactionId) {
    log:printInfo("Transaction: " + transactionId + " aborted");
}