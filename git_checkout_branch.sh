#!/bin/bash

# Git分支切换脚本
# 用法: git_checkout_branch.sh [OPTIONS] <directory> <repo_name> <branch_name>
#
# 参数:
#   directory    - 本地目录路径（如果不存在会自动创建）
#   repo_name    - GitHub仓库名称（格式：owner/repo，例如：paytend-2023/database-migration）
#   branch_name  - 分支名称
#
# 选项:
#   -t, --token-script <path>  - Token生成脚本路径（默认：paytend-generate-git-token.py）
#   -f, --force                - 强制切换分支（丢弃本地更改）
#   -p, --pull                 - 切换后执行pull（默认启用）
#   -h, --help                 - 显示帮助信息
#
# 示例:
#   ./git_checkout_branch.sh ~/database-migration paytend-2023/database-migration feature/waylen/database-feature
#   ./git_checkout_branch.sh -f ~/my-repo owner/repo-name main

# 默认配置
TOKEN_SCRIPT="paytend-generate-git-token.py"
FORCE_CHECKOUT=false
DO_PULL=true

# 解析选项
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--token-script)
            TOKEN_SCRIPT="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_CHECKOUT=true
            shift
            ;;
        -p|--pull)
            DO_PULL=true
            shift
            ;;
        --no-pull)
            DO_PULL=false
            shift
            ;;
        -h|--help)
            cat << EOF
Git分支切换脚本

用法: $0 [OPTIONS] <directory> <repo_name> <branch_name>

参数:
  directory    本地目录路径（如果不存在会自动创建）
  repo_name    GitHub仓库名称（格式：owner/repo）
  branch_name  分支名称

选项:
  -t, --token-script <path>  Token生成脚本路径（默认：~/Paytend-DBA-generate-token.py）
  -f, --force                强制切换分支（丢弃本地更改）
  -p, --pull                 切换后执行pull（默认启用）
  --no-pull                  切换后不执行pull
  -h, --help                 显示帮助信息

示例:
  $0 ~/database-migration paytend-2023/database-migration feature/waylen/database-feature
  $0 -f ~/my-repo owner/repo-name main
EOF
            exit 0
            ;;
        -*)
            echo "错误：未知选项 $1"
            echo "使用 -h 或 --help 查看帮助信息"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# 检查必需参数
if [ $# -lt 3 ]; then
    echo "错误：缺少必需参数"
    echo "用法: $0 [OPTIONS] <directory> <repo_name> <branch_name>"
    echo "使用 -h 或 --help 查看帮助信息"
    exit 1
fi

DIRECTORY="$1"
REPO_NAME="$2"
BRANCHNAME="$3"

# 验证repo名称格式
if [[ ! "$REPO_NAME" =~ ^[^/]+/[^/]+$ ]]; then
    echo "错误：repo名称格式不正确，应为 owner/repo"
    echo "示例：paytend-2023/database-migration"
    exit 1
fi

# 展开 ~ 路径（如果使用）
if [[ "$TOKEN_SCRIPT" == ~* ]]; then
    TOKEN_SCRIPT="${TOKEN_SCRIPT/#\~/$HOME}"
fi

# 检查token脚本是否存在
if [ ! -f "$TOKEN_SCRIPT" ]; then
    echo "错误：Token生成脚本不存在: $TOKEN_SCRIPT"
    echo ""
    echo "请检查："
    echo "1. 脚本路径是否正确"
    echo "2. 使用 -t 选项指定正确的路径"
    echo "   例如: $0 -t /path/to/Paytend-DBA-generate-token.py ..."
    exit 1
fi

# 检查Python3是否可用
if ! command -v python3 &> /dev/null; then
    echo "错误：未找到 python3 命令"
    exit 1
fi

# 生成token
echo "正在生成GitHub token..."
TOKEN_OUTPUT=$(python3 "$TOKEN_SCRIPT" 2>&1)
TOKEN_EXIT_CODE=$?

if [ $TOKEN_EXIT_CODE -ne 0 ] || [ -z "$TOKEN_OUTPUT" ]; then
    echo "错误：无法生成token"
    echo ""
    echo "Token脚本输出:"
    echo "$TOKEN_OUTPUT"
    echo ""
    
    # 检查是否是JWT库问题
    if echo "$TOKEN_OUTPUT" | grep -q "AttributeError: module 'jwt' has no attribute 'encode'"; then
        echo "检测到JWT库问题。解决方案："
        echo ""
        echo "1. 卸载错误的jwt包："
        echo "   pip3 uninstall jwt -y"
        echo ""
        echo "2. 安装正确的PyJWT包："
        echo "   pip3 install PyJWT"
        echo ""
        echo "或者使用sudo（如果需要）："
        echo "   sudo pip3 uninstall jwt -y"
        echo "   sudo pip3 install PyJWT"
        echo ""
        echo "3. 验证安装："
        echo "   python3 -c 'import jwt; print(jwt.__version__)'"
    fi
    
    exit 1
fi

TOKEN="$TOKEN_OUTPUT"

# 创建目录（如果不存在）
if [ ! -d "$DIRECTORY" ]; then
    echo "目录不存在，正在创建: $DIRECTORY"
    mkdir -p "$DIRECTORY"
fi

# 切换到目录
cd "$DIRECTORY" || {
    echo "错误：无法切换到目录: $DIRECTORY"
    exit 1
}

# 检查是否是git仓库
if [ ! -d ".git" ]; then
    echo "当前目录不是git仓库，正在初始化..."
    git init
    git remote add origin "https://x-access-token:$TOKEN@github.com/$REPO_NAME.git" 2>/dev/null || \
    git remote set-url origin "https://x-access-token:$TOKEN@github.com/$REPO_NAME.git"
else
    # 设置remote URL（使用token进行认证）
    echo "设置remote URL..."
    git remote set-url origin "https://x-access-token:$TOKEN@github.com/$REPO_NAME.git"
fi

# 如果强制切换，先清理本地更改
if [ "$FORCE_CHECKOUT" = true ]; then
    echo "强制模式：清理本地更改..."
    git reset --hard HEAD 2>/dev/null
    git clean -fd 2>/dev/null
fi

# 从remote fetch分支信息
echo "正在fetch分支: $BRANCHNAME"
git fetch origin "$BRANCHNAME" 2>&1

if [ $? -ne 0 ]; then
    echo "警告：fetch分支失败，可能分支不存在或没有权限"
fi

# 检查本地是否有未提交的更改
if [ "$FORCE_CHECKOUT" = false ] && ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "警告：本地有未提交的更改"
    echo "使用 -f 或 --force 选项可以强制切换分支（会丢弃本地更改）"
    read -p "是否继续？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "操作已取消"
        exit 1
    fi
fi

# 切换到分支（如果本地不存在则创建并跟踪远程分支）
echo "正在切换到分支: $BRANCHNAME"
if git show-ref --verify --quiet refs/heads/"$BRANCHNAME"; then
    # 本地分支存在
    git checkout "$BRANCHNAME"
    if [ $? -ne 0 ]; then
        echo "错误：无法切换到本地分支: $BRANCHNAME"
        exit 1
    fi
else
    # 本地分支不存在，尝试创建并跟踪远程分支
    git checkout -b "$BRANCHNAME" "origin/$BRANCHNAME" 2>/dev/null || {
        echo "错误：无法创建分支或远程分支不存在: $BRANCHNAME"
        echo "请确认分支名称是否正确，或使用 -f 选项强制创建"
        exit 1
    }
fi

# Pull最新代码（如果启用）
if [ "$DO_PULL" = true ]; then
    echo "正在pull最新代码..."
    git pull origin "$BRANCHNAME"
    if [ $? -ne 0 ]; then
        echo "警告：pull失败，但分支已切换"
    fi
fi

echo "完成！当前分支: $BRANCHNAME"
echo "目录: $DIRECTORY"
git branch --show-current 2>/dev/null || echo "分支: $BRANCHNAME"

