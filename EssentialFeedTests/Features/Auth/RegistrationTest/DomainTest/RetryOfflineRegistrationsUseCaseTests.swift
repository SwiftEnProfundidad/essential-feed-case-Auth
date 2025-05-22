func test_retryWhenApiCallFails_shouldKeepDataInOfflineStoreAndReturnError() async {
    let registrationData = anyRegistrationData()
    let expectedError = anyNSError()

    let (sut, spy) = makeSUT()
    spy.stubLoadAllResult([registrationData])
    spy.stubRegistrationResult(.failure(expectedError))

    let results = await sut.execute()

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.error as NSError?, expectedError)
    XCTAssertEqual(spy.receivedMessages, [
        .loadAll,
        .register(registrationData),
        .loadAll // Verifica que NO hubo .delete
    ])
}
