-- 验证数据库迁移是否成功
-- 执行此查询应该返回所有已创建的对象

-- 1. 检查 player_locations 表是否存在
SELECT 'player_locations 表' AS 检查项,
       CASE WHEN EXISTS (
           SELECT 1 FROM information_schema.tables
           WHERE table_schema = 'public'
           AND table_name = 'player_locations'
       ) THEN '✅ 存在' ELSE '❌ 不存在' END AS 状态;

-- 2. 检查 count_nearby_players 函数是否存在
SELECT 'count_nearby_players 函数' AS 检查项,
       CASE WHEN EXISTS (
           SELECT 1 FROM pg_proc
           WHERE proname = 'count_nearby_players'
       ) THEN '✅ 存在' ELSE '❌ 不存在' END AS 状态;

-- 3. 检查 suggest_poi_count 函数是否存在
SELECT 'suggest_poi_count 函数' AS 检查项,
       CASE WHEN EXISTS (
           SELECT 1 FROM pg_proc
           WHERE proname = 'suggest_poi_count'
       ) THEN '✅ 存在' ELSE '❌ 不存在' END AS 状态;

-- 4. 检查 earthdistance 扩展是否启用
SELECT 'earthdistance 扩展' AS 检查项,
       CASE WHEN EXISTS (
           SELECT 1 FROM pg_extension
           WHERE extname = 'earthdistance'
       ) THEN '✅ 已启用' ELSE '❌ 未启用' END AS 状态;

-- 5. 检查表结构（显示列信息）
SELECT
    '表结构' AS 检查项,
    column_name AS 列名,
    data_type AS 数据类型
FROM information_schema.columns
WHERE table_name = 'player_locations'
ORDER BY ordinal_position;
