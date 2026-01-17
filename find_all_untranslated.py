#!/usr/bin/env python3
import re
import os

# 搜索所有 Swift 文件中需要翻译的硬编码中文字符串
def find_untranslated_chinese():
    chinese_pattern = re.compile(r'(Text|Label|Button|TextField|navigationTitle|ProgressView|Section)\s*\(\s*"([^"]*[\u4e00-\u9fff]+[^"]*)"')

    issues = []

    for root, dirs, files in os.walk('EarthLord'):
        # 跳过隐藏目录和Pods
        dirs[:] = [d for d in dirs if not d.startswith('.') and d != 'Pods']

        for file in files:
            if file.endswith('.swift'):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        for line_num, line in enumerate(f, 1):
                            # 跳过注释行
                            if line.strip().startswith('//'):
                                continue

                            # 查找硬编码中文（不在 NSLocalizedString 中）
                            if 'NSLocalizedString' not in line:
                                matches = chinese_pattern.findall(line)
                                for match in matches:
                                    component, text = match
                                    issues.append({
                                        'file': file_path,
                                        'line': line_num,
                                        'component': component,
                                        'text': text,
                                        'full_line': line.strip()
                                    })
                except:
                    pass

    return issues

print('🔍 正在搜索所有未翻译的硬编码中文字符串...\n')
issues = find_untranslated_chinese()

if issues:
    print(f'⚠️  发现 {len(issues)} 处未翻译的中文字符串:\n')

    # 按文件分组显示
    by_file = {}
    for issue in issues:
        file = issue['file'].replace('EarthLord/', '')
        if file not in by_file:
            by_file[file] = []
        by_file[file].append(issue)

    for file, file_issues in sorted(by_file.items()):
        print(f'\n📄 {file}:')
        for issue in file_issues:
            print(f'  行{issue["line"]}: {issue["component"]}("{issue["text"]}")')
else:
    print('✅ 所有硬编码中文字符串都已翻译！')
