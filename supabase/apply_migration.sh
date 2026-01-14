#!/bin/bash

# 地球新主 - 数据库迁移脚本
# 自动执行 player_locations 表和 RPC 函数的创建

echo "🚀 开始执行数据库迁移..."
echo ""

# Supabase 项目信息
PROJECT_URL="https://vuqfufnrxzsmkzmhtuhw.supabase.co"
MIGRATION_FILE="$(dirname "$0")/migrations/20260114_create_player_locations.sql"

echo "📋 项目信息："
echo "   URL: $PROJECT_URL"
echo "   迁移文件: $MIGRATION_FILE"
echo ""

# 检查迁移文件是否存在
if [ ! -f "$MIGRATION_FILE" ]; then
    echo "❌ 错误：找不到迁移文件"
    echo "   路径: $MIGRATION_FILE"
    exit 1
fi

echo "✅ 迁移文件存在"
echo ""

# 提示用户
echo "⚠️  需要在 Supabase Dashboard 中执行以下步骤："
echo ""
echo "1. 打开浏览器访问："
echo "   https://supabase.com/dashboard/project/vuqfufnrxzsmkzmhtuhw/editor"
echo ""
echo "2. 左侧菜单点击 'SQL Editor'"
echo ""
echo "3. 点击 'New Query'"
echo ""
echo "4. 复制以下 SQL 并粘贴到编辑器："
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$MIGRATION_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "5. 点击 'Run' 按钮执行"
echo ""
echo "6. 确认看到以下成功消息："
echo "   ✅ Extensions created: cube, earthdistance"
echo "   ✅ Table created: player_locations"
echo "   ✅ Functions created: count_nearby_players, suggest_poi_count"
echo ""

# 询问是否已完成
read -p "完成后按 Enter 继续，或按 Ctrl+C 取消... " -r
echo ""

echo "🎉 迁移步骤说明已完成！"
echo ""
echo "现在重新运行 App 并开始探索，应该能看到："
echo "   📍 开始位置上报（每 30 秒）"
echo "   ✅ 位置上报成功: (XX.XXXX, XXX.XXXX)"
echo "   🔍 查询附近玩家数量..."
echo "   ✅ 附近有 0 个在线玩家 - 独行者"
echo "   💡 建议显示 1 个 POI（附近 0 个玩家）"
echo "   ✅ 找到 1 个 POI"
echo ""
