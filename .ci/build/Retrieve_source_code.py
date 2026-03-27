import os
import json
import xml.etree.ElementTree as ET
import subprocess
from pathlib import Path

def load_repositories(xml_file):
    """从XML文件加载仓库信息"""
    # 检查文件是否存在
    if not os.path.exists(xml_file):
        print(f"错误：找不到文件 {xml_file}")
        return []
    
    tree = ET.parse(xml_file)
    root = tree.getroot()
    repos = []
    
    for repo in root.findall('repo'):
        url = repo.get('url')
        dir_name = repo.get('dir')
        repos.append({
            'url': url,
            'dir_name': dir_name
        })
    
    return repos

def get_git_info(path):
    """获取Git仓库信息"""
    try:
        # 检查是否是Git仓库
        result = subprocess.run(
            ['git', '-C', path, 'rev-parse', '--is-inside-work-tree'],
            capture_output=True,
            text=True,
            check=True
        )
        
        # 获取当前分支或tag
        branch_result = subprocess.run(
            ['git', '-C', path, 'rev-parse', '--abbrev-ref', 'HEAD'],
            capture_output=True,
            text=True,
            check=True
        )
        branch = branch_result.stdout.strip()
        
        # 如果是HEAD，说明在detached HEAD状态，尝试获取tag
        if branch == 'HEAD':
            tag_result = subprocess.run(
                ['git', '-C', path, 'describe', '--tags', '--exact-match'],
                capture_output=True,
                text=True
            )
            if tag_result.returncode == 0:
                branch = tag_result.stdout.strip()
            else:
                # 获取最近的tag或commit
                tag_result = subprocess.run(
                    ['git', '-C', path, 'describe', '--tags', '--always'],
                    capture_output=True,
                    text=True
                )
                branch = tag_result.stdout.strip()
        
        # 获取commit ID
        commit_result = subprocess.run(
            ['git', '-C', path, 'rev-parse', 'HEAD'],
            capture_output=True,
            text=True,
            check=True
        )
        commit_id = commit_result.stdout.strip()
        
        return {
            'branch_tag': branch,
            'commit_id': commit_id
        }
    
    except subprocess.CalledProcessError:
        return None
    except Exception as e:
        print(f"获取Git信息时出错 ({path}): {e}")
        return None

def find_matching_directories(root_dir, target_dirs):
    """查找匹配的目录"""
    matches = []
    
    for dirpath, dirnames, filenames in os.walk(root_dir):
        for dirname in dirnames:
            if dirname in target_dirs:
                full_path = os.path.join(dirpath, dirname)
                matches.append({
                    'path': full_path,
                    'dir_name': dirname
                })
    
    return matches

def main():
    # XML文件路径
    xml_file_path = "BoostKit_CI/sourcecode/bigdata/code.xml"
    
    # 加载仓库信息
    repos_info = load_repositories(xml_file_path)
    
    if not repos_info:
        return
    
    # 提取目标目录名称
    target_dirs = [repo['dir_name'] for repo in repos_info]
    
    # 创建目录名到URL的映射
    dir_to_url = {repo['dir_name']: repo['url'] for repo in repos_info}
    
    # 查找当前目录及其子目录中匹配的目录
    current_dir = os.getcwd()
    print(f"正在搜索目录: {current_dir}")
    matching_dirs = find_matching_directories(current_dir, target_dirs)
    
    # 收集结果
    results = []
    for match in matching_dirs:
        print(f"检查目录: {match['path']}")
        git_info = get_git_info(match['path'])
        if git_info:
            result_item = {
                'url': dir_to_url[match['dir_name']],
                '目录名称': match['dir_name'],
                '代码分支或tag': git_info['branch_tag'],
                'commitid': git_info['commit_id']
            }
            results.append(result_item)
            print(f"✓ 找到Git仓库: {match['dir_name']} - {git_info['branch_tag']} - {git_info['commit_id'][:8]}")
        else:
            print(f"✗ 不是Git仓库: {match['path']}")
    
    # 保存到JSON文件
    output_file = "repositories_info.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=4)
    
    print(f"\n已生成 {output_file} 文件")
    print(f"共找到 {len(results)} 个有效代码仓")
    
    if results:
        print("\n结果概览:")
        for item in results:
            print(f"- {item['目录名称']}: {item['代码分支或tag']} ({item['commitid'][:8]})")

if __name__ == "__main__":
    main()
