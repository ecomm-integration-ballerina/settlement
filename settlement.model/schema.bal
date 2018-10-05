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
    string createTime,
    json invoiceId,
    json creditMemoId,
    string[] itemIds,
    float amount,
    float transactionFeeAmount,
    string processorApprovalCode,

};

public type Settlements record {
    Settlement[] settlements,
};

public type SettlementDAO record {
    int transactionId,
    string orderNo,
    json request,
    string processFlag,
    int retryCount,
    string errorMessage,
    string createdTime,
    string lastUpdatedTime,
};

public type SettlementsDAO record {
    SettlementDAO[] settlements,
};

public function settlementToString(Settlement s) returns string {
    json settlementJson = check <json> s;
    return settlementJson.toString();
}