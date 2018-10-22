import ballerina/http;
import ballerina/log;
import ballerina/mysql;
import raj/settlement.model as model;

endpoint http:Listener settlementListener {
    port: 8280
};

@http:ServiceConfig {
    basePath: "/data/settlement"
}
service<http:Service> settlementDataAPI bind settlementListener {

    @http:ResourceConfig {
        methods:["POST"],
        path: "/",
        body: "settlement"
    }
    addSettlement (endpoint outboundEp, http:Request req, model:SettlementDAO settlement) {
        http:Response res = addSettlement(req, untaint settlement);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["GET"],
        path: "/"
    }
    getSettlements (endpoint outboundEp, http:Request req) {
        http:Response res = getSettlements(req);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }   

    @http:ResourceConfig {
        methods:["PUT"],
        path: "/process-flag/",
        body: "settlement"
    }
    updateProcessFlag (endpoint outboundEp, http:Request req, model:SettlementDAO settlement) {
        http:Response res = updateProcessFlag(req, untaint settlement);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["PUT"],
        path: "/process-flag/batch/",
        body: "settlements"
    }
    batchUpdateProcessFlag (endpoint outboundEp, http:Request req, model:SettlementsDAO settlements) {
        http:Response res = batchUpdateProcessFlag(req, settlements);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }     
}