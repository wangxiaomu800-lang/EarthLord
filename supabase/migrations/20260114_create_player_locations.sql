-- 地球新主 - 玩家位置追踪系统
-- 创建时间: 2026-01-14
-- 功能：实现附近玩家检测和动态 POI 分配

-- ============================================================================
-- 1. 启用 PostgreSQL 地理扩展
-- ============================================================================

-- 启用 cube 扩展（earthdistance 的依赖）
CREATE EXTENSION IF NOT EXISTS cube;

-- 启用 earthdistance 扩展（用于地理距离计算）
CREATE EXTENSION IF NOT EXISTS earthdistance;


-- ============================================================================
-- 2. PLAYER_LOCATIONS 表（玩家位置记录）
-- ============================================================================

-- 创建 player_locations 表
CREATE TABLE IF NOT EXISTS public.player_locations (
    player_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    last_update_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_online BOOLEAN NOT NULL DEFAULT TRUE,

    -- 用于快速地理查询的 EARTH 类型字段
    earth_location EARTH,

    -- 添加约束确保坐标有效
    CONSTRAINT valid_latitude CHECK (latitude >= -90 AND latitude <= 90),
    CONSTRAINT valid_longitude CHECK (longitude >= -180 AND longitude <= 180)
);

-- 创建 GIST 索引（用于高效的地理范围查询）
CREATE INDEX IF NOT EXISTS idx_player_locations_earth
    ON public.player_locations USING GIST(earth_location);

-- 创建时间索引（用于在线状态过滤）
CREATE INDEX IF NOT EXISTS idx_player_locations_last_update
    ON public.player_locations(last_update_time);

-- 创建在线状态索引（用于快速过滤在线玩家）
CREATE INDEX IF NOT EXISTS idx_player_locations_is_online
    ON public.player_locations(is_online);

-- 启用 RLS（行级安全策略）
ALTER TABLE public.player_locations ENABLE ROW LEVEL SECURITY;

-- RLS 策略：玩家可以读取所有位置记录（用于统计，但不暴露具体位置）
CREATE POLICY "已认证用户可以读取位置记录用于统计"
    ON public.player_locations
    FOR SELECT
    TO authenticated
    USING (true);

-- RLS 策略：玩家只能更新自己的位置
CREATE POLICY "玩家可以更新自己的位置"
    ON public.player_locations
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = player_id)
    WITH CHECK (auth.uid() = player_id);

-- RLS 策略：玩家可以插入自己的位置记录
CREATE POLICY "玩家可以插入自己的位置记录"
    ON public.player_locations
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = player_id);


-- ============================================================================
-- 3. 自动更新 earth_location 字段的触发器
-- ============================================================================

-- 创建触发器函数：当经纬度更新时，自动更新 earth_location 字段
CREATE OR REPLACE FUNCTION update_earth_location()
RETURNS TRIGGER AS $$
BEGIN
    -- 将经纬度转换为 EARTH 类型
    NEW.earth_location := ll_to_earth(NEW.latitude, NEW.longitude);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为 player_locations 表添加触发器
CREATE TRIGGER update_player_location_earth
    BEFORE INSERT OR UPDATE OF latitude, longitude ON public.player_locations
    FOR EACH ROW
    EXECUTE FUNCTION update_earth_location();


-- ============================================================================
-- 4. RPC 函数：统计附近玩家数量
-- ============================================================================

-- 函数：count_nearby_players
-- 参数：
--   user_lat: 用户纬度
--   user_lng: 用户经度
--   radius_meters: 查询半径（米），默认 1000 米
-- 返回：附近在线玩家数量（不包括自己）
CREATE OR REPLACE FUNCTION count_nearby_players(
    user_lat DOUBLE PRECISION,
    user_lng DOUBLE PRECISION,
    radius_meters DOUBLE PRECISION DEFAULT 1000
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    nearby_count INTEGER;
    online_threshold TIMESTAMPTZ;
BEGIN
    -- 计算在线阈值（5 分钟前）
    online_threshold := NOW() - INTERVAL '5 minutes';

    -- 查询附近在线玩家数量（排除自己）
    SELECT COUNT(*)
    INTO nearby_count
    FROM public.player_locations
    WHERE
        player_id != auth.uid()  -- 排除自己
        AND last_update_time >= online_threshold  -- 只统计在线玩家
        AND is_online = true  -- 明确在线状态
        AND earth_box(
            ll_to_earth(user_lat, user_lng),
            radius_meters
        ) @> ll_to_earth(latitude, longitude)  -- 地理范围预过滤（使用索引）
        AND earth_distance(
            ll_to_earth(user_lat, user_lng),
            ll_to_earth(latitude, longitude)
        ) <= radius_meters;  -- 精确距离过滤

    RETURN nearby_count;
END;
$$;


-- ============================================================================
-- 5. RPC 函数：建议 POI 显示数量
-- ============================================================================

-- 函数：suggest_poi_count
-- 参数：
--   nearby_player_count: 附近玩家数量
-- 返回：建议显示的 POI 数量
-- 规则：
--   0 人 → 1 个 POI（独行者）
--   1-5 人 → 3 个 POI（低密度）
--   6-20 人 → 6 个 POI（中密度）
--   20+ 人 → 20 个 POI（高密度，上限）
CREATE OR REPLACE FUNCTION suggest_poi_count(
    nearby_player_count INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- 根据附近玩家数量返回建议的 POI 显示数量
    CASE
        WHEN nearby_player_count = 0 THEN RETURN 1;  -- 独行者：1 个
        WHEN nearby_player_count BETWEEN 1 AND 5 THEN RETURN 3;  -- 低密度：3 个
        WHEN nearby_player_count BETWEEN 6 AND 20 THEN RETURN 6;  -- 中密度：6 个
        ELSE RETURN 20;  -- 高密度：全部（上限 20，iOS 地理围栏限制）
    END CASE;
END;
$$;


-- ============================================================================
-- 6. 添加注释（用于文档说明）
-- ============================================================================

COMMENT ON TABLE public.player_locations IS '玩家位置记录表，用于附近玩家检测';
COMMENT ON COLUMN public.player_locations.player_id IS '玩家 ID（关联到 auth.users）';
COMMENT ON COLUMN public.player_locations.latitude IS '纬度';
COMMENT ON COLUMN public.player_locations.longitude IS '经度';
COMMENT ON COLUMN public.player_locations.last_update_time IS '最后更新时间（用于判断在线状态）';
COMMENT ON COLUMN public.player_locations.is_online IS '是否在线（用户主动标记）';
COMMENT ON COLUMN public.player_locations.earth_location IS 'EARTH 类型字段（自动计算，用于地理查询）';

COMMENT ON FUNCTION count_nearby_players IS '统计附近在线玩家数量（不包括自己）';
COMMENT ON FUNCTION suggest_poi_count IS '根据附近玩家数量建议 POI 显示数量';
