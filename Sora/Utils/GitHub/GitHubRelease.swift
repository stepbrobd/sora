//
//  GitHubRelease.swift
//  Sora
//
//  Created by Francesco on 29/12/24.
//

import Foundation

struct GitHubRelease: Codable {
    let url: String
    let assetsUrl: String
    let uploadUrl: String
    let htmlUrl: String
    let id: Int
    let author: Author
    let nodeId: String
    let tagName: String
    let targetCommitish: String
    let name: String
    let draft: Bool
    let prerelease: Bool
    let createdAt: String
    let publishedAt: String
    let assets: [Asset]
    let tarballUrl: String
    let zipballUrl: String
    let body: String
    
    enum CodingKeys: String, CodingKey {
        case url
        case assetsUrl = "assets_url"
        case uploadUrl = "upload_url"
        case htmlUrl = "html_url"
        case id
        case author
        case nodeId = "node_id"
        case tagName = "tag_name"
        case targetCommitish = "target_commitish"
        case name
        case draft
        case prerelease
        case createdAt = "created_at"
        case publishedAt = "published_at"
        case assets
        case tarballUrl = "tarball_url"
        case zipballUrl = "zipball_url"
        case body
    }
    
    struct Author: Codable {
        let login: String
        let id: Int
        let nodeId: String
        let avatarUrl: String
        let gravatarId: String
        let url: String
        let htmlUrl: String
        let followersUrl: String
        let followingUrl: String
        let gistsUrl: String
        let starredUrl: String
        let subscriptionsUrl: String
        let organizationsUrl: String
        let reposUrl: String
        let eventsUrl: String
        let receivedEventsUrl: String
        let type: String
        let siteAdmin: Bool
        
        enum CodingKeys: String, CodingKey {
            case login
            case id
            case nodeId = "node_id"
            case avatarUrl = "avatar_url"
            case gravatarId = "gravatar_id"
            case url
            case htmlUrl = "html_url"
            case followersUrl = "followers_url"
            case followingUrl = "following_url"
            case gistsUrl = "gists_url"
            case starredUrl = "starred_url"
            case subscriptionsUrl = "subscriptions_url"
            case organizationsUrl = "organizations_url"
            case reposUrl = "repos_url"
            case eventsUrl = "events_url"
            case receivedEventsUrl = "received_events_url"
            case type
            case siteAdmin = "site_admin"
        }
    }
    
    struct Asset: Codable {
        let url: String
        let id: Int
        let nodeId: String
        let name: String
        let label: String?
        let uploader: Author
        let contentType: String
        let state: String
        let size: Int
        let downloadCount: Int
        let createdAt: String
        let updatedAt: String
        let browserDownloadUrl: String
        
        enum CodingKeys: String, CodingKey {
            case url
            case id
            case nodeId = "node_id"
            case name
            case label
            case uploader
            case contentType = "content_type"
            case state
            case size
            case downloadCount = "download_count"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case browserDownloadUrl = "browser_download_url"
        }
    }
}
