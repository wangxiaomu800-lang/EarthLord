//
//  AIGeneratedItem.swift
//  EarthLord
//
//  AI 生成物品相关数据模型
//  用于 Edge Function 请求和响应
//

import Foundation

/// AI 生成的物品
struct AIGeneratedItem: Codable {
    let name: String        // AI 生成的独特名称
    let category: String    // 分类（医疗/食物/工具/武器/材料）
    let rarity: String      // 稀有度（common/uncommon/rare/epic/legendary）
    let story: String       // 背景故事
}

/// Edge Function 请求体
struct GenerateItemRequest: Codable {
    let poi: POIInfo
    let itemCount: Int

    struct POIInfo: Codable {
        let name: String
        let type: String
        let dangerLevel: Int
    }
}

/// Edge Function 响应体
struct GenerateItemResponse: Codable {
    let success: Bool
    let items: [AIGeneratedItem]?
    let error: String?
}
