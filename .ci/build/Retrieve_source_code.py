#!/usr/bin/env python3
"""
源码信息收集脚本

功能：
1. 从 code.xml 加载仓库定义
2. 在工作空间中搜索匹配的 Git 仓库
3. 收集每个仓库的 URL、分支/tag、commit ID
4. 输出 JSON 格式的仓库信息

用法：
    python3 Retrieve_source_code.py [xml_file] [workspace] [output_file]

参数：
    xml_file     - code.xml 文件路径（默认：.ci/build/code.xml）
    workspace    - 工作空间目录（默认：当前目录）
    output_file  - 输出 JSON 文件路径（默认：repositories_info.json）
"""

import os
import sys
import json
import argparse
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class RepositoryInfoCollector:
    """Git 仓库信息收集器"""

    # 默认搜索深度
    DEFAULT_SEARCH_DEPTH = 4

    def __init__(self, xml_path: str, workspace: str, output_path: str):
        """
        初始化收集器

        Args:
            xml_path: code.xml 文件路径
            workspace: 工作空间根目录
            output_path: 输出 JSON 文件路径
        """
        self.xml_path = Path(xml_path).resolve()
        self.workspace = Path(workspace).resolve()
        self.output_path = Path(output_path).resolve()
        self.repos_config: List[Dict[str, str]] = []

    def load_repository_config(self) -> bool:
        """
        从 XML 文件加载仓库配置

        Returns:
            加载成功返回 True，失败返回 False
        """
        if not self.xml_path.exists():
            print(f"错误：找不到配置文件 {self.xml_path}", file=sys.stderr)
            return False

        try:
            tree = ET.parse(self.xml_path)
            root = tree.getroot()

            for repo in root.findall('repo'):
                url = repo.get('url')
                dir_name = repo.get('dir')
                if url and dir_name:
                    self.repos_config.append({
                        'url': url,
                        'dir_name': dir_name
                    })

            if not self.repos_config:
                print(f"警告：配置文件 {self.xml_path} 中没有有效的仓库定义", file=sys.stderr)

            return True

        except ET.ParseError as e:
            print(f"错误：XML 文件格式无效 - {e}", file=sys.stderr)
            return False
        except Exception as e:
            print(f"错误：解析配置文件失败 - {e}", file=sys.stderr)
            return False

    def get_git_info(self, repo_path: Path) -> Optional[Dict[str, str]]:
        """
        获取 Git 仓库信息

        Args:
            repo_path: 仓库路径

        Returns:
            包含 branch/tag 和 commit_id 的字典，失败返回 None
        """
        if not (repo_path / '.git').exists():
            return None

        try:
            # 检查是否是有效的 Git 仓库
            subprocess.run(
                ['git', '-C', str(repo_path), 'rev-parse', '--is-inside-work-tree'],
                capture_output=True,
                check=True,
                text=True
            )

            # 获取当前分支
            branch_result = subprocess.run(
                ['git', '-C', str(repo_path), 'rev-parse', '--abbrev-ref', 'HEAD'],
                capture_output=True,
                check=True,
                text=True
            )
            branch = branch_result.stdout.strip()

            # 如果是 detached HEAD，尝试获取 tag
            if branch == 'HEAD':
                tag_result = subprocess.run(
                    ['git', '-C', str(repo_path), 'describe', '--tags', '--exact-match'],
                    capture_output=True,
                    text=True
                )
                if tag_result.returncode == 0:
                    branch = tag_result.stdout.strip()
                else:
                    # 获取最近的 tag 或 commit
                    tag_result = subprocess.run(
                        ['git', '-C', str(repo_path), 'describe', '--tags', '--always'],
                        capture_output=True,
                        text=True
                    )
                    branch = tag_result.stdout.strip()

            # 获取 commit ID
            commit_result = subprocess.run(
                ['git', '-C', str(repo_path), 'rev-parse', 'HEAD'],
                capture_output=True,
                check=True,
                text=True
            )
            commit_id = commit_result.stdout.strip()

            return {
                'branch_tag': branch,
                'commit_id': commit_id
            }

        except subprocess.CalledProcessError:
            return None
        except Exception as e:
            print(f"警告：获取 Git 信息失败 ({repo_path}) - {e}", file=sys.stderr)
            return None

    def find_repositories(self) -> List[Dict[str, str]]:
        """
        在工作空间中搜索仓库并收集信息

        Returns:
            仓库信息列表
        """
        if not self.workspace.exists():
            print(f"错误：工作空间目录不存在 {self.workspace}", file=sys.stderr)
            return []

        # 创建目录名到 URL 的映射
        dir_to_url = {repo['dir_name']: repo['url'] for repo in self.repos_config}
        target_dirs = set(dir_to_url.keys())

        results = []
        found_dirs = set()  # 用于去重

        print(f"搜索目录: {self.workspace}")
        print(f"目标仓库: {', '.join(target_dirs)}")
        print("-" * 50)

        # 限制搜索深度
        for depth in range(self.DEFAULT_SEARCH_DEPTH + 1):
            pattern = '*/' * depth if depth > 0 else '*'

            for item in self.workspace.glob(pattern):
                if item.is_dir() and item.name in target_dirs and item.name not in found_dirs:
                    git_info = self.get_git_info(item)
                    if git_info:
                        result = {
                            'repoUrl': dir_to_url[item.name],
                            'repoBranch': git_info['branch_tag'],
                            'commitId': git_info['commit_id'],
                            'dirName': item.name
                        }
                        results.append(result)
                        found_dirs.add(item.name)
                        print(f"✓ {item.name}: {git_info['branch_tag']} ({git_info['commit_id'][:8]})")

        return results

    def save_results(self, results: List[Dict[str, str]]) -> bool:
        """
        保存结果到 JSON 文件

        Args:
            results: 仓库信息列表

        Returns:
            保存成功返回 True，失败返回 False
        """
        try:
            with open(self.output_path, 'w', encoding='utf-8') as f:
                json.dump(results, f, ensure_ascii=False, indent=4)

            print("-" * 50)
            print(f"已生成: {self.output_path}")
            print(f"共找到: {len(results)} 个仓库")

            return True

        except Exception as e:
            print(f"错误：保存结果失败 - {e}", file=sys.stderr)
            return False

    def run(self) -> int:
        """
        执行收集流程

        Returns:
            退出码（0 表示成功）
        """
        # 1. 加载配置
        if not self.load_repository_config():
            return 1

        # 2. 搜索仓库
        results = self.find_repositories()

        # 3. 保存结果
        if not self.save_results(results):
            return 1

        return 0


def parse_args() -> argparse.Namespace:
    """解析命令行参数"""
    parser = argparse.ArgumentParser(
        description='收集工作空间中 Git 仓库的信息',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
    # 使用默认参数
    python3 Retrieve_source_code.py

    # 指定配置文件和工作空间
    python3 Retrieve_source_code.py /path/to/code.xml /workspace

    # 指定输出文件
    python3 Retrieve_source_code.py code.xml . output.json
        """
    )

    parser.add_argument(
        'xml_file',
        nargs='?',
        default='.ci/build/code.xml',
        help='code.xml 配置文件路径（默认：.ci/build/code.xml）'
    )

    parser.add_argument(
        'workspace',
        nargs='?',
        default='.',
        help='工作空间目录（默认：当前目录）'
    )

    parser.add_argument(
        'output_file',
        nargs='?',
        default='repositories_info.json',
        help='输出 JSON 文件路径（默认：repositories_info.json）'
    )

    return parser.parse_args()


def main() -> int:
    """主入口"""
    args = parse_args()

    collector = RepositoryInfoCollector(
        xml_path=args.xml_file,
        workspace=args.workspace,
        output_path=args.output_file
    )

    return collector.run()


if __name__ == '__main__':
    sys.exit(main())