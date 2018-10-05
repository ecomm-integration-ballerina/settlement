public type Settlement record {
    string id,
    string paymentId,
    string ^"type",
    string referenceId,
    string processorTransactionId,
    string currency,
    string countryCode,
    string paymentProcessor,
    string paymentMethod,
    string paymentBrand,
};

public function settlementToString(Settlement s) returns string {
    json settlementJson = check <json> s;
    return settlementJson.toString();
}