import ballerina/http;
import ballerina/log;
import ballerina/mysql;
import raj/settlement.model as model;

endpoint http:Listener settlementImportInboundDispatcherListener {
    port: 8280
};

@http:ServiceConfig {
    basePath: "/settlement"
}
service<http:Service> settlementAPI bind settlementImportInboundDispatcherListener {

    @http:ResourceConfig {
        methods:["POST"],
        path: "/",
        consumes: ["text/plain", "application/json"],
        produces: ["application/json"],
        body: "settlement"
    }
    addSettlement (endpoint outboundEp, http:Request req, model:Settlement settlement) {
        http:Response res = addSettlement(req, settlement);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }       
}