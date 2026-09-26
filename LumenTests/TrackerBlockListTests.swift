import Foundation
import Testing
@testable import Lumen

@MainActor
struct TrackerBlockListTests {
    @Test func advertisingDomainBecomesThirdPartyBlockRuleSparingItsOwnersSites() {
        let list = TrackerBlockList(entries: [
            DisconnectEntry(categoryKey: "Advertising", entityName: "AdCo", domains: ["adco.net"]),
            DisconnectEntry(categoryKey: "Content", entityName: "AdCo", domains: ["adco-cdn.com"])
        ])

        let expected = ContentRule(
            trigger: ContentRule.Trigger(
                urlFilter: #"^https?://([^/]*\.)?adco\.net[:/]"#,
                loadType: ["third-party"],
                unlessDomain: ["*adco-cdn.com", "*adco.net"]
            ),
            action: ContentRule.Action(type: .block)
        )

        #expect(list.contentRules().first == expected)
    }

    @Test func pathEntryBlocksOnlyThatPath() {
        let list = TrackerBlockList(entries: [
            DisconnectEntry(categoryKey: "Advertising", entityName: "Search", domains: ["search.example/ads"])
        ])

        #expect(list.contentRules().first?.trigger.urlFilter == #"^https?://([^/]*\.)?search\.example/ads"#)
    }

    @Test func domainAlsoListedAsContentIsNotBlocked() {
        let list = TrackerBlockList(entries: [
            DisconnectEntry(categoryKey: "Advertising", entityName: "AdCo", domains: ["shared-cdn.example"]),
            DisconnectEntry(categoryKey: "Content", entityName: "CdnCo", domains: ["shared-cdn.example"])
        ])

        #expect(list.contentRules().count == 1)
    }

    @Test func aggressiveEmailCategoryIsNotBlocked() {
        let list = TrackerBlockList(entries: [
            DisconnectEntry(categoryKey: "EmailAggressive", entityName: "MailCo", domains: ["mailco.example"])
        ])

        #expect(list.contentRules().count == 1)
    }

    @Test func trackingRulesEndWithThirdPartyCookieBlocking() {
        let list = TrackerBlockList(entries: [
            DisconnectEntry(categoryKey: "Analytics", entityName: "StatCo", domains: ["statco.example"])
        ])

        let expected = ContentRule(
            trigger: ContentRule.Trigger(urlFilter: ".*", loadType: ["third-party"]),
            action: ContentRule.Action(type: .blockCookies)
        )

        #expect(list.contentRules().last == expected)
    }

    @Test func mixedContentRuleUpgradesEveryHTTPLoad() {
        let expected = ContentRule(
            trigger: ContentRule.Trigger(urlFilter: "^http://"),
            action: ContentRule.Action(type: .makeHTTPS)
        )

        #expect(TrackerBlockList.mixedContentRules == [expected])
    }

    @Test func encodedRulesUseWebKitKeys() throws {
        let rule = ContentRule(
            trigger: ContentRule.Trigger(urlFilter: ".*", loadType: ["third-party"]),
            action: ContentRule.Action(type: .blockCookies)
        )

        let json = try TrackerBlockList.encode([rule])

        #expect(json == #"[{"action":{"type":"block-cookies"},"trigger":{"load-type":["third-party"],"url-filter":".*"}}]"#)
    }

    @Test func countsEachBlockedTrackerHostOnce() throws {
        let list = TrackerBlockList(entries: [
            DisconnectEntry(categoryKey: "Advertising", entityName: "AdCo", domains: ["adco.net"])
        ])

        let hosts = list.blockedTrackerHosts(
            in: [
                try #require(URL(string: "https://px.adco.net/a.gif")),
                try #require(URL(string: "https://px.adco.net/b.gif")),
                try #require(URL(string: "https://adco.net/tag.js"))
            ],
            pageURL: try #require(URL(string: "https://news.example/story"))
        )

        #expect(hosts == ["px.adco.net", "adco.net"])
    }

    @Test func trackerOwnedByThePagesEntityIsNotCounted() throws {
        let list = TrackerBlockList(entries: [
            DisconnectEntry(categoryKey: "Advertising", entityName: "AdCo", domains: ["adco.net"]),
            DisconnectEntry(categoryKey: "Content", entityName: "AdCo", domains: ["adco-cdn.com"])
        ])

        let hosts = list.blockedTrackerHosts(
            in: [try #require(URL(string: "https://px.adco.net/a.gif"))],
            pageURL: try #require(URL(string: "https://www.adco-cdn.com/"))
        )

        #expect(hosts.isEmpty)
    }

    @Test func hostsOutsideTheBlockListAreNotCounted() throws {
        let list = TrackerBlockList(entries: [
            DisconnectEntry(categoryKey: "Advertising", entityName: "AdCo", domains: ["adco.net"])
        ])

        let hosts = list.blockedTrackerHosts(
            in: [
                try #require(URL(string: "https://fonts.example/font.woff2")),
                try #require(URL(string: "https://notadco.net/x.js"))
            ],
            pageURL: try #require(URL(string: "https://news.example/"))
        )

        #expect(hosts.isEmpty)
    }

    @Test func pathEntryCountsOnlyRequestsUnderThatPath() throws {
        let list = TrackerBlockList(entries: [
            DisconnectEntry(categoryKey: "Advertising", entityName: "Search", domains: ["search.example/ads"])
        ])

        let hosts = list.blockedTrackerHosts(
            in: [
                try #require(URL(string: "https://search.example/maps/tile.png")),
                try #require(URL(string: "https://www.search.example/ads/pixel"))
            ],
            pageURL: try #require(URL(string: "https://news.example/"))
        )

        #expect(hosts == ["www.search.example"])
    }
}
