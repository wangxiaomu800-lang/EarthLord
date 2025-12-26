# 地球新主 - Supabase 数据库配置

## 数据库结构

本项目使用 Supabase 作为后端数据库，包含以下核心表：

### 1. profiles（用户资料）
- `id`: UUID（主键，关联 auth.users）
- `username`: TEXT（用户名，唯一）
- `avatar_url`: TEXT（头像 URL）
- `created_at`: TIMESTAMPTZ（创建时间）
- `updated_at`: TIMESTAMPTZ（更新时间）

**特性**：
- ✅ 启用了 RLS（行级安全）
- ✅ 任何人可查看资料
- ✅ 用户只能修改自己的资料
- ✅ 新用户注册时自动创建 profile

### 2. territories（领地）
- `id`: UUID（主键）
- `user_id`: UUID（用户 ID，外键）
- `name`: TEXT（领地名称）
- `path`: JSONB（路径点数组）
- `area`: DOUBLE PRECISION（面积，平方米）
- `created_at`: TIMESTAMPTZ（创建时间）
- `updated_at`: TIMESTAMPTZ（更新时间）

**特性**：
- ✅ 启用了 RLS
- ✅ 任何人可查看领地
- ✅ 已认证用户可创建领地
- ✅ 用户只能修改/删除自己的领地

**path 格式示例**：
```json
[
  {"lat": 39.9042, "lng": 116.4074},
  {"lat": 39.9052, "lng": 116.4084},
  {"lat": 39.9062, "lng": 116.4094}
]
```

### 3. pois（兴趣点）
- `id`: TEXT（外部 POI ID）
- `poi_type`: ENUM（类型）
- `name`: TEXT（名称）
- `latitude`: DOUBLE PRECISION（纬度）
- `longitude`: DOUBLE PRECISION（经度）
- `discovered_by`: UUID（发现者 ID）
- `discovered_at`: TIMESTAMPTZ（发现时间）

**POI 类型**：
- `hospital` - 医院
- `supermarket` - 超市
- `factory` - 工厂
- `gas_station` - 加油站
- `police` - 警察局
- `school` - 学校
- `park` - 公园
- `restaurant` - 餐厅
- `other` - 其他

**特性**：
- ✅ 启用了 RLS
- ✅ 任何人可查看 POI
- ✅ 已认证用户可发现新 POI
- ✅ 发现者可更新 POI 信息

## 如何使用 Migration

### 方法 1：通过 Supabase Dashboard（推荐）

1. 访问 [https://vuqfufnrxzsmkzmhtuhw.supabase.co](https://vuqfufnrxzsmkzmhtuhw.supabase.co)
2. 登录你的 Supabase 账号
3. 进入项目的 **SQL Editor**
4. 复制 `migrations/20251226_create_core_tables.sql` 的全部内容
5. 粘贴到 SQL Editor 中
6. 点击 **Run** 执行

### 方法 2：通过 Supabase CLI

```bash
# 1. 安装 Supabase CLI（如果还没安装）
brew install supabase/tap/supabase

# 2. 登录
supabase login

# 3. 链接到你的项目
supabase link --project-ref vuqfufnrxzsmkzmhtuhw

# 4. 应用 migration
supabase db push
```

### 方法 3：通过 Supabase MCP（如果已配置）

在 Claude Code 中运行：
```bash
/mcp
# 选择 Supabase，然后使用 apply_migration 工具
```

## 验证安装

执行 migration 后，你可以通过以下方式验证：

### 1. 在 Supabase Dashboard 中检查
- 进入 **Table Editor**
- 应该能看到 `profiles`、`territories`、`pois` 三个表

### 2. 使用 SQL 查询
```sql
-- 检查表是否存在
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('profiles', 'territories', 'pois');

-- 检查 RLS 是否启用
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('profiles', 'territories', 'pois');
```

### 3. 使用 SupabaseTestView 测试
在应用中：
1. 运行 EarthLord 应用
2. 进入"更多"标签页
3. 点击"Supabase 连接测试"
4. 点击"测试连接"按钮
5. 应该显示"✅ 连接成功"

## 下一步

数据库配置完成后，你可以：

1. **测试数据库连接**
   - 使用应用中的 SupabaseTestView

2. **实现用户认证**
   - 集成 Supabase Auth
   - 实现登录/注册功能

3. **开发核心功能**
   - 领地绘制和保存
   - POI 发现和记录
   - 用户资料管理

4. **配置 Storage**（如果需要上传头像）
   ```sql
   -- 创建 avatars bucket
   INSERT INTO storage.buckets (id, name, public)
   VALUES ('avatars', 'avatars', true);
   ```

## 连接信息

- **Supabase URL**: `https://vuqfufnrxzsmkzmhtuhw.supabase.co`
- **Publishable Key**: `sb_publishable_sej6ww803g00vIuiXFjhFQ_JdRV2QHk`

⚠️ **注意**：不要将 service_role key 提交到 Git！
