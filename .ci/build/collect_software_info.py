#!/usr/bin/env python3
"""
软件包元数据生成脚本

功能：
1. 计算软件包的 SHA256 摘要
2. 收集工作空间中 Git 仓库的信息（复用 Retrieve_source_code.py）
3. 生成包含 SHA256、仓库信息、构建时间的 JSON 元数据文件

用法：
    python3 collect_software_info.py [options] <package_file>

参数：
    package_file     软件包文件路径（必需）

选项：
    --xml FILE       code.xml 配置文件路径（默认：.ci/build/code.xml）
    --workspace DIR  工作空间目录（默认：当前目录）
    --output FILE    输出 JSON 文件路径（默认：<package_file>.json）

示例：
    # 基本用法
    python3 collect_software_info.py BoostKit-omniruntime-gluten-2.0.0.zip

    # 指定参数
    python3 collect_software_info.py --xml code.xml --workspace /opt package.zip
"""

import os
import sys
import json
import hashlib
import argparse
import subprocess
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional


class SoftwareMetadataGenerator:
    """软件包元数据生成器"""

    # 分块读取大小
    CHUNK_SIZE = 8192

    def __init__(self, package_path: str, xml_path: str, workspace: str, output_path: Optional[str] = None):
        """
        初始化生成器

        Args:
            package_path: 软件包文件路径
            xml_path: code.xml 配置文件路径
            workspace: 工作空间目录
            output_path: 输出 JSON 文件路径（可选）
        """
        self.package_path = Path(package_path).resolve()
        self.xml_path = Path(xml_path).resolve()
        self.workspace = Path(workspace).resolve()
        self.output_path = Path(output_path).resolve() if output_path else None

    def calculate_sha256(self) -> str:
        """
        计算软件包的 SHA256 摘要

        Returns:
            SHA256 十六进制字符串
        """
        if not self.package_path.exists():
            raise FileNotFoundError(f"软件包文件不存在: {self.package_path}")

        sha256_hash = hashlib.sha256()

        with open(self.package_path, "rb") as f:
            for chunk in iter(lambda: f.read(self.CHUNK_SIZE), b""):
                sha256_hash.update(chunk)

        return sha256_hash.hexdigest()

    def collect_repo_info(self) -> List[Dict[str, str]]:
        """
        收集工作空间中 Git 仓库的信息

        复用 Retrieve_source_code.py 脚本

        Returns:
            仓库信息列表
        """
        # 动态导入 Retrieve_source_code 模块
        script_dir = Path(__file__).parent
        retrieve_script = script_dir / "Retrieve_source_code.py"

        if not retrieve_script.exists():
            print(f"警告：找不到 Retrieve_source_code.py，跳过仓库信息收集", file=sys.stderr)
            return []

        try:
            # 使用 subprocess 调用 Retrieve_source_code.py
            import tempfile

            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as tmp:
                tmp_output = tmp.name

            try:
                result = subprocess.run(
                    [
                        sys.executable,
                        str(retrieve_script),
                        str(self.xml_path),
                        str(self.workspace),
                        tmp_output
                    ],
                    capture_output=True,
                    text=True
                )

                if result.returncode != 0:
                    print(f"警告：仓库信息收集失败 - {result.stderr}", file=sys.stderr)
                    return []

                # 读取结果
                with open(tmp_output, 'r', encoding='utf-8') as f:
                    repo_info = json.load(f)

                return repo_info

            finally:
                # 清理临时文件
                if os.path.exists(tmp_output):
                    os.remove(tmp_output)

        except Exception as e:
            print(f"警告：收集仓库信息时出错 - {e}", file=sys.stderr)
            return []

    def generate_metadata(self) -> Dict:
        """
        生成完整的元数据

        Returns:
            元数据字典
        """
        print(f"计算 SHA256: {self.package_path.name}...")
        sha256_sum = self.calculate_sha256()
        print(f"SHA256: {sha256_sum}")

        print(f"收集仓库信息...")
        repo_info = self.collect_repo_info()
        print(f"找到 {len(repo_info)} 个仓库")

        build_time = datetime.now().strftime("%Y%m%d%H%M%S")

        return {
            "sha256Sum": sha256_sum,
            "repoInfo": repo_info,
            "buildTime": build_time
        }

    def save_metadata(self, metadata: Dict) -> Path:
        """
        保存元数据到 JSON 文件

        Args:
            metadata: 元数据字典

        Returns:
            输出文件路径
        """
        if self.output_path:
            output_file = self.output_path
        else:
            output_file = Path(f"{self.package_path}.json")

        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(metadata, f, ensure_ascii=False, indent=4)

        return output_file

    def run(self) -> int:
        """
        执行元数据生成流程

        Returns:
            退出码（0 表示成功）
        """
        try:
            # 生成元数据
            metadata = self.generate_metadata()

            # 保存结果
            output_file = self.save_metadata(metadata)

            print(f"\n元数据已生成: {output_file}")
            print(f"  - SHA256: {metadata['sha256Sum'][:16]}...")
            print(f"  - 仓库数: {len(metadata['repoInfo'])}")
            print(f"  - 构建时间: {metadata['buildTime']}")

            return 0

        except FileNotFoundError as e:
            print(f"错误：{e}", file=sys.stderr)
            return 1
        except Exception as e:
            print(f"错误：生成元数据失败 - {e}", file=sys.stderr)
            return 1


def parse_args() -> argparse.Namespace:
    """解析命令行参数"""
    parser = argparse.ArgumentParser(
        description='生成软件包的元数据（SHA256、仓库信息、构建时间）',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
    # 基本用法
    python3 collect_software_info.py package.zip

    # 指定配置文件和工作空间
    python3 collect_software_info.py --xml code.xml --workspace /opt package.zip

    # 指定输出文件
    python3 collect_software_info.py --output metadata.json package.zip
        """
    )

    parser.add_argument(
        'package_file',
        help='软件包文件路径'
    )

    parser.add_argument(
        '--xml',
        default='.ci/build/code.xml',
        help='code.xml 配置文件路径（默认：.ci/build/code.xml）'
    )

    parser.add_argument(
        '--workspace',
        default='.',
        help='工作空间目录（默认：当前目录）'
    )

    parser.add_argument(
        '--output', '-o',
        help='输出 JSON 文件路径（默认：<package_file>.json）'
    )

    return parser.parse_args()


def main() -> int:
    """主入口"""
    args = parse_args()

    generator = SoftwareMetadataGenerator(
        package_path=args.package_file,
        xml_path=args.xml,
        workspace=args.workspace,
        output_path=args.output
    )

    return generator.run()


if __name__ == '__main__':
    sys.exit(main())