import ballerina/io;
import ballerina/config;
import ballerina/log;
import ballerina/mb;
import ballerina/http;
import ballerina/time;
import wso2/soap;
import raj/settlement.model as model;

type Address record {
    string countryCode;
    string stateCode;
    string add1;
    string add2;
    string city;
    string zip;
};

int maxRetryCount = config:getAsInt("settlement.outbound.sap.maxRetryCount");

endpoint http:Client settlementDataServiceEndpoint {
    url: config:getAsString("settlement.data.service.url")
};

endpoint soap:Client sapClient {
    clientConfig: {
        url: config:getAsString("sap.api.url")
    }
};

endpoint mb:SimpleQueueSender tmcQueue {
    host: config:getAsString("tmc.mb.host"),
    port: config:getAsInt("tmc.mb.port"),
    queueName: config:getAsString("tmc.mb.queueName")
};

function processSettlementToSap (model:SettlementDAO settlementDAORec) returns boolean {

    int tid = settlementDAORec.transactionId;
    string orderNo = settlementDAORec.orderNo;
    int retryCount = settlementDAORec.retryCount ;

    xml idoc = createIDOC(settlementDAORec);
    soap:SoapRequest soapRequest = {
        soapAction: "urn:addSettlement",
        payload: idoc
    };

    log:printInfo("Sending settlement to sap tid : " + tid + ", order : " + orderNo
                        + ". Payload:\n" + io:sprintf("%s", idoc));

    var ret = sapClient->sendReceive("/", soapRequest);

    boolean success;
    match ret {
        soap:SoapResponse soapResponse => {

            xml payload = soapResponse.payload;
            if (payload.msg.getTextValue() == "Errored") {

                log:printInfo("Failed to send settlement to sap tid :  " + tid + ", order : " + orderNo
                    + ". Payload : " + io:sprintf("%s", payload));
                updateProcessFlag(tid, orderNo, retryCount + 1, "E", "Errored");
            } else {

                log:printInfo("Sent settlement to sap tid : " + tid + ", order : " + orderNo);
                updateProcessFlag(tid, orderNo, retryCount, "C", "Sent to SAP");
                success = true;
            }
        }
        soap:SoapError soapError => {
            log:printInfo("Failed to send settlement to sap tid : " + tid + ", order : " + orderNo
                + ". Payload : " + soapError.message);
            updateProcessFlag(tid, orderNo, retryCount + 1, "E", soapError.message);
        }
    }

    if (success) {
        publishToTMCQueue(<string> idoc, orderNo, "SENT");
    } else {
        publishToTMCQueue(<string> idoc, orderNo, "NOT_SENT");
    }

    return true;
}

function updateProcessFlag(int tid, string orderNo, int retryCount, string processFlag, string errorMessage) {

    json updateSettlement = {
        "transactionId": tid,
        "processFlag": processFlag,
        "retryCount": retryCount,
        "errorMessage": errorMessage
    };

    http:Request req = new;
    req.setJsonPayload(untaint updateSettlement);
    
    log:printInfo("Calling settlementDataServiceEndpoint.updateProcessFlag tid : " 
        + tid + ", order : " + orderNo + ". Payload : " + updateSettlement.toString());

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
            log:printError("Error while calling settlementDataServiceEndpoint.updateProcessFlag tid : " 
                    + tid + ", order : " + orderNo, err = err);
        }
    }
}

function notifyOperation() {
    // sending email alerts
    log:printInfo("Notifying operations");
}

function createIDOC (model:SettlementDAO settlementDAORec) returns xml {

    model:Settlement settlementRec = check <model:Settlement> settlementDAORec.request;
    time:Time createTime = time:parse(settlementRec.createTime, "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");

    xml settlements = xml `<ZECOMMSETTLEMENT>
            <IDOC BEGIN="1">
            </IDOC>
        </ZECOMMSETTLEMENT>`;

    xml settlementsHeader = xml `<EDI_DC40 SEGMENT="1">
            <TABNAM>EDI_DC40</TABNAM>
            <MANDT>301</MANDT>
            <DOCNUM>0000002344096796</DOCNUM>
            <DOCREL>740</DOCREL>
            <STATUS>30</STATUS>
            <DIRECT>1</DIRECT>
            <OUTMOD>2</OUTMOD>
            <IDOCTYP>ZECOMMSETTLEMENT</IDOCTYP>
            <MESTYP>ZSETTLEMENT</MESTYP>
            <STDMES>ZSETTL</STDMES>
            <SNDPOR>WSO2_ZECOMM</SNDPOR>
            <SNDPRT>LS</SNDPRT>
            <SNDPRN>ZZECOMM_ECOM</SNDPRN>
            <RCVPOR>DEST</RCVPOR>
            <RCVPRT>LS</RCVPRT>
            <RCVPRN>DEST</RCVPRN>
            <CREDAT>{{createTime.format("yyyyMMdd")}}</CREDAT>
            <CRETIM>{{createTime.format("HHmmss")}}</CRETIM>
        </EDI_DC40>`; 

    string txType;
    if (settlementRec.^"type" == "CAPTURE") {
        txType = "INVOICE";
    } else {
        txType = "REFUND";
    }

    xml settlementsData = xml `<ZECOMMSETTLEMENT SEGMENT="1">
            <ZSETTID>{{settlementRec.processorTransactionId}}</ZSETTID>
            <DMBTR>{{settlementRec.amount}}</DMBTR>
            <WAERK>{{settlementRec.currency}}</WAERK>
            <ZBLCORD>{{settlementRec.referenceId}}</ZBLCORD>
            <ZSETTDT>{{createTime.format("yyyyMMdd")}}</ZSETTDT>
            <ZSETTCD>{{settlementRec.processorApprovalCode}}</ZSETTCD>
            <ZPTYPE>{{settlementRec.paymentBrand}}</ZPTYPE>
            <ZBKCHG>{{settlementRec.transactionFeeAmount}}</ZBKCHG>
            <ZSETTTYPE>{{txType}}</ZSETTTYPE>
            <LAND1>{{settlementRec.countryCode}}</LAND1>
        </ZECOMMSETTLEMENT>`;

    string invoiceId = settlementRec.invoiceId.toString();
    if (invoiceId != "" && invoiceId != "null" && invoiceId != null) {
        xml invoiceIdHeader = xml `<VBELN>{{invoiceId}}</VBELN>`;
        xml settlementsDataChildren = settlementsData.* + invoiceIdHeader;
        settlementsData.setChildren(settlementsDataChildren);
    }

    string creditMemoId = settlementRec.creditMemoId.toString();
    if (creditMemoId != "" && creditMemoId != "null" && creditMemoId != null) {
        xml creditMemoIdHeader = xml `<VBELN>{{creditMemoId}}</VBELN>`;
        xml settlementsDataChildren = settlementsData.* + creditMemoIdHeader;
        settlementsData.setChildren(settlementsDataChildren);
    }

    settlements.selectDescendants("IDOC").setChildren(settlementsHeader + settlementsData);
    return settlements;
}

function publishToTMCQueue (string req, string orderNo, string status) {

    time:Time time = time:currentTime();
    string transactionDate = time.format("yyyyMMddHHmmssSSS");
    json payload = {
        "externalKey": null,
        "processInstanceID": orderNo,
        "receiverDUNSno":"ECC" ,
        "senderDUNSno": "OPS",
        "transactionDate": transactionDate,
        "version": "V01",
        "transactionFlow": "OUTBOUND",
        "transactionStatus": status,
        "documentID": null,
        "documentName": "SETTLEMENT_OPS_ECC",
        "documentNo": "SETTLEMENT_OPS_ECC_" + orderNo,
        "documentSize": null,
        "documentStatus": status,
        "documentType": "xml",
        "payload": req,
        "appName": "SETTLEMENT_OPS_ECC",
        "documentFilename": null
     };

    match (tmcQueue.createTextMessage(payload.toString())) {
        error err => {
            log:printError("!Queued in tmcQueue", err=err);
        }
        mb:Message msg => {
            var ret = tmcQueue->send(msg);
            match ret {
                error err => {
                    log:printError("!Queued in tmcQueue", err=err);
                }
                () => {
                    log:printInfo("Queued in tmcQueue");
                }
            }
        }
    }
}