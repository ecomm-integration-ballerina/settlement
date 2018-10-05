import ballerina/io;
import ballerina/config;
import ballerina/log;
import ballerina/mb;
import ballerina/http;
import ballerina/time;
import raj/settlement.model as model;

endpoint mb:SimpleTopicSubscriber settlementOutboundTopic {
    host: config:getAsString("settlement.mb.host"),
    port: config:getAsInt("settlement.mb.port"),
    topicPattern: config:getAsString("settlement.mb.topicName")
};

service<mb:Consumer> settlementOutboundTopicSubscriber bind settlementOutboundTopic {

    onMessage(endpoint consumer, mb:Message message) {

        json settlementJson;
        match message.getTextMessageContent() {

            string settlementString => {
                io:StringReader sr = new(settlementString);
                settlementJson = check sr.readJson();
                model:SettlementDAO settlementDAORec = check <model:SettlementDAO> settlementJson;
                int tid = settlementDAORec.transactionId;
                string orderNo = settlementDAORec.orderNo;

                log:printInfo("Received settlement tid : " + tid + ", order : " 
                                + orderNo + " from " + config:getAsString("settlement.mb.topicName") + " topic");

                boolean success = processSettlementToSap(settlementDAORec);
            }

            error e => {
                log:printError("Error occurred while reading message from " 
                                + config:getAsString("settlement.mb.topicName") + " topic", err = e);
            }
        }
    }
}