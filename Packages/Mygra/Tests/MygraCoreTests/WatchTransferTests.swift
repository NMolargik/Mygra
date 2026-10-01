//
//  WatchTransferTests.swift
//  MygraCoreTests
//

import Foundation
import Testing
import MygraCore

@Suite("Watch wire protocol")
struct WatchTransferTests {
    @Test func messageRoundTrips() {
        let message = WatchMessage(command: .startMigraine, painLevel: 7, stressLevel: 3)
        #expect(WatchMessage(payload: message.payload) == message)
        #expect(WatchMessage(payload: WatchMessage(request: .status).payload).request == .status)
    }

    @Test func unknownCommandsDecodeAsNil() {
        let message = WatchMessage(payload: ["command": "explode"])
        #expect(message.command == nil)
        #expect(message.request == nil)
    }

    @Test func replyRoundTrips() {
        let id = UUID()
        let reply = WatchCommandReply(success: true, migraineID: id)
        #expect(WatchCommandReply(payload: reply.payload) == reply)
        let failure = WatchCommandReply(success: false, error: .alreadyOngoing)
        #expect(WatchCommandReply(payload: failure.payload) == failure)
    }
}
