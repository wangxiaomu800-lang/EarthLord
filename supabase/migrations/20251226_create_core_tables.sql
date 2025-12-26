-- 地球新主 - 核心数据表创建脚本
-- 创建时间: 2025-12-26

-- ============================================================================
-- 1. PROFILES 表（用户资料）
-- ============================================================================

-- 创建 profiles 表
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 为 profiles 表创建索引
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);

-- 启用 RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS 策略：任何人都可以查看资料
CREATE POLICY "公开查看用户资料"
    ON public.profiles
    FOR SELECT
    USING (true);

-- RLS 策略：用户只能插入自己的资料
CREATE POLICY "用户可以创建自己的资料"
    ON public.profiles
    FOR INSERT
    WITH CHECK (auth.uid() = id);

-- RLS 策略：用户只能更新自己的资料
CREATE POLICY "用户可以更新自己的资料"
    ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- RLS 策略：用户只能删除自己的资料
CREATE POLICY "用户可以删除自己的资料"
    ON public.profiles
    FOR DELETE
    USING (auth.uid() = id);


-- ============================================================================
-- 2. TERRITORIES 表（领地）
-- ============================================================================

-- 创建 territories 表
CREATE TABLE IF NOT EXISTS public.territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    path JSONB NOT NULL, -- 存储路径点数组 [{lat, lng}, ...]
    area DOUBLE PRECISION NOT NULL, -- 面积（平方米）
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 为 territories 表创建索引
CREATE INDEX IF NOT EXISTS idx_territories_user_id ON public.territories(user_id);
CREATE INDEX IF NOT EXISTS idx_territories_created_at ON public.territories(created_at DESC);

-- 启用 RLS
ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;

-- RLS 策略：任何人都可以查看领地
CREATE POLICY "公开查看领地"
    ON public.territories
    FOR SELECT
    USING (true);

-- RLS 策略：已认证用户可以创建领地
CREATE POLICY "已认证用户可以创建领地"
    ON public.territories
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- RLS 策略：用户只能更新自己的领地
CREATE POLICY "用户可以更新自己的领地"
    ON public.territories
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- RLS 策略：用户只能删除自己的领地
CREATE POLICY "用户可以删除自己的领地"
    ON public.territories
    FOR DELETE
    USING (auth.uid() = user_id);


-- ============================================================================
-- 3. POIS 表（兴趣点）
-- ============================================================================

-- 创建 POI 类型枚举
CREATE TYPE poi_type AS ENUM (
    'hospital',      -- 医院
    'supermarket',   -- 超市
    'factory',       -- 工厂
    'gas_station',   -- 加油站
    'police',        -- 警察局
    'school',        -- 学校
    'park',          -- 公园
    'restaurant',    -- 餐厅
    'other'          -- 其他
);

-- 创建 pois 表
CREATE TABLE IF NOT EXISTS public.pois (
    id TEXT PRIMARY KEY,  -- 外部 POI ID（如高德/Google Maps ID）
    poi_type poi_type NOT NULL,
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    discovered_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    discovered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- 添加约束确保坐标有效
    CONSTRAINT valid_latitude CHECK (latitude >= -90 AND latitude <= 90),
    CONSTRAINT valid_longitude CHECK (longitude >= -180 AND longitude <= 180)
);

-- 为 pois 表创建索引
CREATE INDEX IF NOT EXISTS idx_pois_type ON public.pois(poi_type);
CREATE INDEX IF NOT EXISTS idx_pois_discovered_by ON public.pois(discovered_by);
CREATE INDEX IF NOT EXISTS idx_pois_location ON public.pois(latitude, longitude);

-- 启用 RLS
ALTER TABLE public.pois ENABLE ROW LEVEL SECURITY;

-- RLS 策略：任何人都可以查看 POI
CREATE POLICY "公开查看 POI"
    ON public.pois
    FOR SELECT
    USING (true);

-- RLS 策略：已认证用户可以发现新 POI
CREATE POLICY "已认证用户可以发现 POI"
    ON public.pois
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = discovered_by);

-- RLS 策略：只有发现者可以更新 POI（如果需要）
CREATE POLICY "发现者可以更新 POI"
    ON public.pois
    FOR UPDATE
    USING (auth.uid() = discovered_by)
    WITH CHECK (auth.uid() = discovered_by);


-- ============================================================================
-- 4. 创建自动更新 updated_at 的函数和触发器
-- ============================================================================

-- 创建更新时间戳函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为 profiles 表添加触发器
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 为 territories 表添加触发器
CREATE TRIGGER update_territories_updated_at
    BEFORE UPDATE ON public.territories
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- ============================================================================
-- 5. 创建自动创建 profile 的触发器
-- ============================================================================

-- 当新用户注册时，自动创建 profile
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', 'user_' || substr(NEW.id::text, 1, 8)),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建触发器
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();


-- ============================================================================
-- 6. 添加注释（可选，用于文档说明）
-- ============================================================================

COMMENT ON TABLE public.profiles IS '用户资料表';
COMMENT ON TABLE public.territories IS '用户领地表';
COMMENT ON TABLE public.pois IS '兴趣点（POI）表';

COMMENT ON COLUMN public.profiles.username IS '用户名（唯一）';
COMMENT ON COLUMN public.profiles.avatar_url IS '用户头像 URL';

COMMENT ON COLUMN public.territories.path IS '领地路径点数组，格式：[{lat, lng}, ...]';
COMMENT ON COLUMN public.territories.area IS '领地面积（平方米）';

COMMENT ON COLUMN public.pois.id IS '外部 POI ID（如高德/Google Maps ID）';
COMMENT ON COLUMN public.pois.discovered_by IS '发现该 POI 的用户 ID';
