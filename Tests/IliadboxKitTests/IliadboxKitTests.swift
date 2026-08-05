import XCTest

@testable import IliadboxKit

final class IliadboxKitTests: XCTestCase {
  func testFormEncodingEscapesMagnetSeparators() throws {
    let data = IliadboxClient.formEncode([
      "download_url": "magnet:?xt=urn:btih:abc&dn=Hello World"
    ])
    let value = try XCTUnwrap(String(data: data, encoding: .utf8))
    XCTAssertEqual(
      value,
      "download_url=magnet%3A%3Fxt%3Durn%3Abtih%3Aabc%26dn%3DHello%20World"
    )
  }

  func testUsagePercentConvertsBytesToBitsAndClamps() {
    XCTAssertEqual(ConnectionStatus.usagePercent(rate: 125_000, bandwidth: 1_000_000), 100)
    XCTAssertEqual(ConnectionStatus.usagePercent(rate: 62_500, bandwidth: 1_000_000), 50)
    XCTAssertEqual(ConnectionStatus.usagePercent(rate: 500_000, bandwidth: 1_000_000), 100)
    XCTAssertEqual(ConnectionStatus.usagePercent(rate: nil, bandwidth: 1_000_000), 0)
  }

  func testAppConfigSelectsFallbackBoxWhenSavedIDIsMissing() {
    let box = BoxProfile(id: "box-1", name: "Casa", baseURL: "https://box.test/api/v15/")
    let config = AppConfig(activeBoxID: "missing", boxes: [box])
    XCTAssertEqual(config.activeBox, box)
  }

  func testCleanConfigurationIsSafeAndHasNoActiveBox() {
    let config = AppConfig()
    XCTAssertNil(config.activeBox)
    XCTAssertTrue(config.boxes.isEmpty)
    XCTAssertEqual(config.schemaVersion, AppConfig.currentSchemaVersion)
    XCTAssertEqual(config.preferences, AppPreferences())
  }

  func testNetworkInputValidationRejectsMalformedOrUnsafeValues() {
    XCTAssertTrue(IliadboxInputValidator.isIPv4Address("192.168.1.42"))
    XCTAssertFalse(IliadboxInputValidator.isIPv4Address("192.168.1.256"))
    XCTAssertFalse(IliadboxInputValidator.isIPv4Address("192.168.1"))
    XCTAssertTrue(IliadboxInputValidator.isMACAddress("AA:bb:01:23:45:67"))
    XCTAssertTrue(IliadboxInputValidator.isMACAddress("AA-BB-01-23-45-67"))
    XCTAssertFalse(IliadboxInputValidator.isMACAddress("AA:BB:CC:DD:EE"))
    XCTAssertTrue(IliadboxInputValidator.isSupportedAPIURL("https://box.test/api/v15/"))
    XCTAssertTrue(IliadboxInputValidator.isSupportedAPIURL("http://192.168.1.254/api/v15/"))
    XCTAssertFalse(IliadboxInputValidator.isSupportedAPIURL("ftp://box.test/api/"))
    XCTAssertFalse(IliadboxInputValidator.isSupportedAPIURL("https://user:secret@box.test/api/"))
  }

  func testMultiBoxConfigurationSelectsExplicitActiveProfile() {
    let home = BoxProfile(id: "home", name: "Casa", baseURL: "https://home.test/api/v15/")
    let studio = BoxProfile(
      id: "studio", name: "Studio", baseURL: "https://studio.test/api/v16/")
    let config = AppConfig(activeBoxID: studio.id, boxes: [home, studio])
    XCTAssertEqual(config.activeBox, studio)
  }

  func testRemovingActiveBoxSelectsFallbackAndRemovingLastUnconfiguresApp() {
    let home = BoxProfile(id: "home", name: "Casa", baseURL: "https://home.test/api/v15/")
    let studio = BoxProfile(
      id: "studio", name: "Studio", baseURL: "https://studio.test/api/v16/")
    var config = AppConfig(activeBoxID: home.id, boxes: [home, studio])
    config.removeBox(id: home.id)
    XCTAssertEqual(config.activeBox, studio)
    XCTAssertEqual(config.activeBoxID, studio.id)

    config.removeBox(id: studio.id)
    XCTAssertNil(config.activeBox)
    XCTAssertNil(config.activeBoxID)
    XCTAssertTrue(config.boxes.isEmpty)
  }

  /// Payload reale di ibxgw8-r1 (fw 4.9.18.2), anonimizzato: `task_id` arriva
  /// come stringa e c'è un campo `path` che il modello non conosce.
  func testDownloadFilesDecodeRealFirmwarePayload() throws {
    let json = """
      {"success":true,"result":[{
        "path":"/SSD/Download/Esempio.S01E01.mkv",
        "id":"6-0",
        "task_id":"6",
        "filepath":"L1NTRC9Eb3dubG9hZC9Fc2VtcGlvLlMwMUUwMS5ta3Y=",
        "preview_url":"http://192.0.2.10:11938/api/latest/btpreview/6/abcdef",
        "mimetype":"video/x-matroska",
        "name":"Esempio.S01E01.mkv",
        "rx":6411734761,
        "status":"done",
        "priority":"normal",
        "error":"none",
        "size":6411734761
      }]}
      """
    let response = try JSONDecoder().decode(
      FbxResponse<[DownloadFile]>.self, from: Data(json.utf8))
    let file = try XCTUnwrap(response.result?.first)
    XCTAssertEqual(file.id, "6-0")
    XCTAssertEqual(file.taskID?.intValue, 6)
    XCTAssertEqual(file.name, "Esempio.S01E01.mkv")
    XCTAssertEqual(file.size, 6_411_734_761)
    XCTAssertEqual(file.received, 6_411_734_761)
    XCTAssertEqual(file.progress, 1)
  }

  func testOnboardingIsConsideredDoneForConfigurationsThatAlreadyHaveABox() throws {
    let upgraded = Data(
      #"{"schemaVersion":3,"activeBoxID":"home","boxes":[{"id":"home","name":"Casa","baseURL":"http://box/api/v15/"}]}"#
        .utf8)
    let config = try JSONDecoder().decode(AppConfig.self, from: upgraded)
    XCTAssertTrue(config.onboardingCompleted)

    let fresh = Data(#"{"schemaVersion":3,"boxes":[]}"#.utf8)
    XCTAssertFalse(try JSONDecoder().decode(AppConfig.self, from: fresh).onboardingCompleted)

    let explicit = Data(#"{"schemaVersion":3,"boxes":[],"onboardingCompleted":true}"#.utf8)
    XCTAssertTrue(try JSONDecoder().decode(AppConfig.self, from: explicit).onboardingCompleted)
  }

  func testPathStepsRebuildEveryFolderOfABase64Path() {
    let pathB64 = Data("/SSD/Download/Film".utf8).base64EncodedString()
    let steps = IliadboxClient.pathSteps(forPathB64: pathB64)
    XCTAssertEqual(steps.map(\.name), ["SSD", "Download", "Film"])
    XCTAssertEqual(
      steps.map(\.pathB64),
      ["/SSD", "/SSD/Download", "/SSD/Download/Film"].map {
        Data($0.utf8).base64EncodedString()
      })
  }

  func testPathStepsAreEmptyForRootOrInvalidInput() {
    XCTAssertTrue(IliadboxClient.pathSteps(forPathB64: IliadboxClient.rootPathB64).isEmpty)
    XCTAssertTrue(IliadboxClient.pathSteps(forPathB64: "non-base64!!").isEmpty)
  }

  func testPreferencesDecodeDefaultsGranularNotificationFlags() throws {
    let data = Data(
      #"{"idleRefreshSeconds":30,"activeRefreshSeconds":5,"notificationsEnabled":false}"#.utf8)
    let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)
    XCTAssertEqual(preferences.idleRefreshSeconds, 30)
    XCTAssertEqual(preferences.activeRefreshSeconds, 5)
    XCTAssertFalse(preferences.notificationsEnabled)
    XCTAssertTrue(preferences.notifyOnStart)
    XCTAssertTrue(preferences.notifyOnCompletion)
    XCTAssertTrue(preferences.notifyOnFailure)
  }

  func testRuntimeConfigDecodesLegacyFileWithoutBoxID() throws {
    let data = Data(#"{"baseURL":"http://box/api/v15/","appToken":"secret"}"#.utf8)
    let config = try JSONDecoder().decode(IbxConfig.self, from: data)
    XCTAssertEqual(config.boxID, BoxProfile.legacyID)
    XCTAssertEqual(config.baseURL, "http://box/api/v15/")
    XCTAssertEqual(config.appToken, "secret")
  }

  func testLegacyConfigurationMigrationPreservesTokenForPrivateConfig() throws {
    let data = Data(
      #"{"baseURL":"https://legacy.test/api/v14/","appToken":"secret-token"}"#.utf8)
    let migration = try XCTUnwrap(ConfigStore.decodeConfiguration(data))
    XCTAssertTrue(migration.wasLegacy)
    XCTAssertEqual(migration.legacyToken, "secret-token")
    XCTAssertEqual(migration.appConfig.activeBox?.id, BoxProfile.legacyID)
    XCTAssertEqual(migration.appConfig.activeBox?.baseURL, "https://legacy.test/api/v14/")

    var migrated = migration.appConfig
    let profileID = try XCTUnwrap(migrated.activeBox?.id)
    let index = try XCTUnwrap(migrated.boxes.firstIndex(where: { $0.id == profileID }))
    migrated.boxes[index].appToken = migration.legacyToken
    let persisted = try JSONEncoder().encode(migrated)
    let text = try XCTUnwrap(String(data: persisted, encoding: .utf8))
    XCTAssertTrue(text.contains("secret-token"))
    XCTAssertTrue(text.contains("appToken"))
  }

  func testDiscoveryBuildsVersionedHTTPSURL() throws {
    let box = try XCTUnwrap(
      DiscoveredBox.parse(
        serviceName: "iliadbox",
        txt: [
          "uid": "box-123",
          "device_name": "iliadbox",
          "device_type": "IliadBox,1",
          "api_version": "15.2",
          "api_base_url": "/api/",
          "api_domain": "example.ibxos.it",
          "https_available": "1",
          "https_port": "12345",
        ]))
    XCTAssertEqual(box.id, "box-123")
    XCTAssertEqual(box.baseURL.absoluteString, "https://example.ibxos.it:12345/api/v15/")
    XCTAssertTrue(box.supportsHTTPS)
  }

  func testDiscoveryFallsBackToHTTPAndNormalizesPath() throws {
    let box = try XCTUnwrap(
      DiscoveredBox.parse(
        serviceName: "Freebox",
        txt: [
          "api_version": "4.0",
          "api_base_url": "gateway-api",
          "api_domain": "mafreebox.freebox.fr",
        ]))
    XCTAssertEqual(box.baseURL.absoluteString, "http://mafreebox.freebox.fr/gateway-api/v4/")
    XCTAssertFalse(box.supportsHTTPS)
  }

  func testDiscoveryRejectsRecordWithoutDomain() {
    XCTAssertNil(DiscoveredBox.parse(serviceName: "Broken", txt: ["api_version": "15.0"]))
  }

  func testClientOpensSignedSessionThroughInjectedTransport() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: configuration)
    StubURLProtocol.handler = { request in
      let path = try XCTUnwrap(request.url?.path)
      if path.hasSuffix("/login") {
        return Self.response(
          request, json: #"{"success":true,"result":{"logged_in":false,"challenge":"challenge"}}"#)
      }
      if path.hasSuffix("/login/session") {
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(Self.body(of: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["app_id"], IliadboxClient.appId)
        XCTAssertFalse(try XCTUnwrap(json["password"]).isEmpty)
        return Self.response(
          request,
          json:
            #"{"success":true,"result":{"session_token":"session","permissions":{"downloader":true}}}"#
        )
      }
      XCTFail("Unexpected path: \(path)")
      return Self.response(request, status: 404, json: "{}")
    }

    let client = IliadboxClient(
      config: IbxConfig(baseURL: "https://box.test/api/v15/", appToken: "token"),
      urlSession: session
    )
    let result = try await client.openSession()
    XCTAssertEqual(result.sessionToken, "session")
    XCTAssertEqual(result.permissions?["downloader"], true)
  }

  func testRevokedTokenIsReportedAsAuthenticationFailure() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    StubURLProtocol.handler = { request in
      Self.response(
        request,
        status: 403,
        json:
          #"{"success":false,"error_code":"invalid_token","msg":"Token revoked"}"#
      )
    }
    let client = IliadboxClient(
      config: IbxConfig(baseURL: "https://box.test/api/v15/", appToken: "revoked"),
      urlSession: URLSession(configuration: configuration)
    )

    do {
      _ = try await client.openSession()
      XCTFail("A revoked token must not open a session")
    } catch let error as FbxError {
      XCTAssertEqual(error.category, .authentication)
    }
  }

  func testOfflineTransportFailurePropagatesWithoutInvalidDecoding() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
    let client = IliadboxClient(
      config: IbxConfig(baseURL: "https://offline.test/api/v15/", appToken: "token"),
      urlSession: URLSession(configuration: configuration)
    )

    do {
      _ = try await client.openSession()
      XCTFail("An offline box must not open a session")
    } catch let error as URLError {
      XCTAssertEqual(error.code, .notConnectedToInternet)
    }
  }

  func testFailureCategoriesSeparateAuthAndPermissions() {
    XCTAssertEqual(FbxError.notPaired.category, .authentication)
    XCTAssertEqual(FbxError.api(code: "invalid_token", message: nil).category, .authentication)
    XCTAssertEqual(FbxError.api(code: "insufficient_rights", message: nil).category, .permission)
    XCTAssertEqual(FbxError.http(status: 503).category, .transport)
    XCTAssertEqual(FbxError.invalidResponse.category, .invalidData)
  }

  func testLanHostDecodesSingleL2IdentityObject() throws {
    let data = Data(
      #"""
      {
        "id":"host-1","primary_name":"Studio","reachable":true,
        "l2ident":{"id":"AA:BB:CC:DD:EE:FF","type":"ethernet"},
        "l3connectivities":[{"addr":"192.168.1.20","af":"ipv4","active":true}]
      }
      """#.utf8)
    let host = try JSONDecoder().decode(LanHost.self, from: data)
    XCTAssertEqual(host.macAddress, "AA:BB:CC:DD:EE:FF")
    XCTAssertEqual(host.ipv4Address, "192.168.1.20")
    XCTAssertEqual(host.l2Identity?.values.count, 1)
  }

  func testLanHostDecodesMultipleL2Identities() throws {
    let data = Data(
      #"""
      {
        "id":"host-2","primary_name":"Mac",
        "l2ident":[{"id":"AA:AA:AA:AA:AA:AA"},{"id":"BB:BB:BB:BB:BB:BB"}]
      }
      """#.utf8)
    let host = try JSONDecoder().decode(LanHost.self, from: data)
    XCTAssertEqual(host.l2Identity?.values.count, 2)
    XCTAssertEqual(host.macAddress, "AA:AA:AA:AA:AA:AA")
  }

  func testWifiFixtureDecodesStringAndIntegerPhysicalValues() throws {
    let bssData = Data(
      #"""
      {
        "id":"00:11:22:33:44:55","phy_id":"1",
        "config":{"enabled":true,"ssid":"Casa","encryption":"wpa2_psk_ccmp","key":"test-key","hide_ssid":false},
        "status":{"state":"active","sta_count":2,"authorized_sta_count":2,"is_main_bss":true}
      }
      """#.utf8)
    let bss = try JSONDecoder().decode(WifiBSS.self, from: bssData)
    XCTAssertEqual(bss.physicalID?.intValue, 1)
    XCTAssertEqual(bss.config?.ssid, "Casa")
    XCTAssertEqual(bss.config?.key, "test-key")

    let apData = Data(
      #"""
      {
        "id":1,"name":"2.4 GHz","status":{"channel_width":"40","primary_channel":6},
        "config":{"band":"2d4g","channel_width":20,"primary_channel":6}
      }
      """#.utf8)
    let ap = try JSONDecoder().decode(WifiAccessPoint.self, from: apData)
    XCTAssertEqual(ap.status?.channelWidth?.intValue, 40)
    XCTAssertEqual(ap.config?.channelWidth?.intValue, 20)
  }

  func testConnectionDecodesAssignedIPv4PortRange() throws {
    let data = Data(#"{"state":"up","ipv4_port_range":[16384,32767]}"#.utf8)
    let status = try JSONDecoder().decode(ConnectionStatus.self, from: data)
    XCTAssertEqual(status.assignedPortRange, 16_384...32_767)
    XCTAssertTrue(try XCTUnwrap(status.assignedPortRange).contains(20_000))
    XCTAssertFalse(try XCTUnwrap(status.assignedPortRange).contains(8_080))
  }

  func testPortForwardingDecodesStringPublicPort() throws {
    let data = Data(
      #"{"id":3,"enabled":true,"ip_proto":"tcp","wan_port_start":"20000","wan_port_end":20000,"lan_ip":"192.168.1.20","lan_port":443,"src_ip":"0.0.0.0","comment":"HTTPS"}"#
        .utf8)
    let rule = try JSONDecoder().decode(PortForwardingRule.self, from: data)
    XCTAssertEqual(rule.wanPortStart.intValue, 20_000)
    XCTAssertEqual(rule.lanIP, "192.168.1.20")
  }

  func testAdvancedCapabilityFixturesDecodeMissingOptionalFields() throws {
    let call = try JSONDecoder().decode(
      CallEntry.self,
      from: Data(
        #"{"id":1,"type":"missed","datetime":1700000000,"number":"0123"}"#.utf8
      ))
    XCTAssertEqual(call.type, "missed")
    XCTAssertNil(call.duration)

    let vpn = try JSONDecoder().decode(
      VPNClientStatus.self,
      from: Data(
        #"{"enabled":false,"state":"down","last_error":"none"}"#.utf8
      ))
    XCTAssertEqual(vpn.state, "down")
    XCTAssertNil(vpn.activeVPN)
  }

  func testAutomationJSONHasStableSortedSnapshot() throws {
    let data = try AutomationJSON.data(
      ["z": 2, "a": ["enabled": true, "count": 1]] as [String: Any])
    XCTAssertEqual(
      String(decoding: data, as: UTF8.self),
      """
      {
        "a" : {
          "count" : 1,
          "enabled" : true
        },
        "z" : 2
      }
      """)
  }

  func testDocumentedFileConflictModesHaveStableWireValues() {
    XCTAssertEqual(FileConflictMode.overwrite.rawValue, "overwrite")
    XCTAssertEqual(FileConflictMode.both.rawValue, "both")
    XCTAssertEqual(FileConflictMode.recent.rawValue, "recent")
    XCTAssertEqual(FileConflictMode.skip.rawValue, "skip")
    XCTAssertEqual(UploadConflictMode.missing.rawValue, "missing")
    XCTAssertEqual(UploadConflictMode.overwrite.rawValue, "overwrite")
    XCTAssertEqual(UploadConflictMode.resume.rawValue, "resume")
  }

  func testCopyRequestSendsSelectedConflictMode() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    StubURLProtocol.handler = { request in
      let path = try XCTUnwrap(request.url?.path)
      if path.hasSuffix("/login") {
        return Self.response(
          request,
          json: #"{"success":true,"result":{"logged_in":false,"challenge":"challenge"}}"#
        )
      }
      if path.hasSuffix("/login/session") {
        return Self.response(
          request,
          json: #"{"success":true,"result":{"session_token":"session"}}"#
        )
      }
      if path.contains("/fs/cp") {
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(Self.body(of: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["mode"] as? String, "skip")
        XCTAssertEqual(json["dst"] as? String, "destination")
        XCTAssertEqual(json["files"] as? [String], ["source"])
        return Self.response(
          request,
          json: #"{"success":true,"result":{"id":42,"state":"queued","type":"cp"}}"#
        )
      }
      XCTFail("Unexpected path: \(path)")
      return Self.response(request, status: 404, json: "{}")
    }
    let client = IliadboxClient(
      config: IbxConfig(baseURL: "https://box.test/api/v15/", appToken: "token"),
      urlSession: URLSession(configuration: configuration)
    )
    let task = try await client.copy(
      pathsB64: ["source"], to: "destination", mode: .skip)
    XCTAssertEqual(task.id, 42)
  }

  func testDownloadDestinationPreservesExistingFiles() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let existing = directory.appendingPathComponent("video.mkv")
    try Data().write(to: existing)

    let destination = IliadboxClient.uniqueDestination(in: directory, name: "video.mkv")
    XCTAssertEqual(destination.lastPathComponent, "video 2.mkv")
    XCTAssertTrue(FileManager.default.fileExists(atPath: existing.path))
  }

  func testParentalPlanningRoundTripPreservesCustomRangesAndMapping() throws {
    let mapping = Array(repeating: ParentalAccessMode.allowed.rawValue, count: 8 * 48)
    let planning = ParentalPlanning(
      resolution: 48,
      customDayRanges: [":fr_bank_holidays"],
      mapping: mapping
    )
    let data = try JSONEncoder().encode(planning)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    XCTAssertEqual(json["resolution"] as? Int, 48)
    XCTAssertEqual(json["cdayranges"] as? [String], [":fr_bank_holidays"])
    XCTAssertEqual((json["mapping"] as? [String])?.count, 384)

    let decoded = try JSONDecoder().decode(ParentalPlanning.self, from: data)
    XCTAssertEqual(decoded.mapping, mapping)
  }

  func testDownloadTransitionsAreDeterministicAndDeduplicated() throws {
    let downloading = try Self.downloadTask(id: 7, status: "downloading")
    XCTAssertTrue(
      DownloadTransitionDetector.events(
        previousStatuses: [:], current: [downloading], hasBaseline: false
      ).isEmpty)
    XCTAssertEqual(
      DownloadTransitionDetector.events(
        previousStatuses: [:], current: [downloading], hasBaseline: true),
      [DownloadTransition(taskID: 7, kind: .started)]
    )
    XCTAssertTrue(
      DownloadTransitionDetector.events(
        previousStatuses: [7: "starting"], current: [downloading], hasBaseline: true
      ).isEmpty)
    XCTAssertTrue(
      DownloadTransitionDetector.events(
        previousStatuses: [7: "downloading"], current: [downloading], hasBaseline: true
      ).isEmpty)

    let completed = try Self.downloadTask(id: 7, status: "done")
    XCTAssertEqual(
      DownloadTransitionDetector.events(
        previousStatuses: [7: "downloading"], current: [completed], hasBaseline: true),
      [DownloadTransition(taskID: 7, kind: .completed)]
    )
    let failed = try Self.downloadTask(id: 7, status: "error", error: "disk_full")
    XCTAssertEqual(
      DownloadTransitionDetector.events(
        previousStatuses: [7: "downloading"], current: [failed], hasBaseline: true),
      [DownloadTransition(taskID: 7, kind: .failed)]
    )
  }

  func testDiagnosticsContainOnlyRedactedOperationalData() throws {
    let report = RedactedDiagnostics(
      generatedAt: Date(timeIntervalSince1970: 0),
      app: .init(version: "0.9.0", bundleID: "it.ivan.IliadBar"),
      macOS: "macOS test",
      box: .init(
        configured: true,
        deviceType: "IliadBox,1",
        apiVersion: "15.0",
        transport: "https",
        paired: true,
        availability: "online"
      ),
      permissions: ["downloads": true],
      capabilities: ["downloads"],
      counts: .init(
        downloads: 1, storageDisks: 1, lanHosts: 2, wifiBSS: 1, dhcpLeases: 2,
        natRules: 0),
      liveEvents: true
    )

    let data = try report.data()
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let box = try XCTUnwrap(json["box"] as? [String: Any])
    XCTAssertEqual(box["transport"] as? String, "https")
    XCTAssertEqual((json["counts"] as? [String: Any])?["downloads"] as? Int, 1)

    let text = try XCTUnwrap(String(data: data, encoding: .utf8))
    for forbiddenKey in [
      "app_token", "session_token", "session_key", "last_status", "base_url",
      "hostname", "ip_address", "mac_address", "device_name", "wifi_key",
    ] {
      XCTAssertFalse(text.contains("\"\(forbiddenKey)\""), forbiddenKey)
    }
    for secretSample in [
      "secret-token-value", "192.0.2.42", "AA:BB:CC:DD:EE:FF", "private-box.local",
    ] {
      XCTAssertFalse(text.contains(secretSample), secretSample)
    }
  }

  private static func response(
    _ request: URLRequest,
    status: Int = 200,
    json: String
  ) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: status,
      httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"]
    )!
    return (response, Data(json.utf8))
  }

  private static func body(of request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
      let count = stream.read(buffer, maxLength: 4096)
      if count <= 0 { break }
      data.append(buffer, count: count)
    }
    return data
  }

  private static func downloadTask(id: Int, status: String, error: String? = nil) throws
    -> DownloadTask
  {
    var object: [String: Any] = ["id": id, "status": status, "name": "Fixture"]
    if let error { object["error"] = error }
    return try JSONDecoder().decode(
      DownloadTask.self, from: JSONSerialization.data(withJSONObject: object))
  }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.handler else {
      client?.urlProtocol(self, didFailWithError: FbxError.invalidResponse)
      return
    }
    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
