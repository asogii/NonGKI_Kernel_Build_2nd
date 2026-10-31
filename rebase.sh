#!/bin/bash
set -e

git fetch upstream

# 尝试变基；若发生冲突，git rebase 会返回非零退出码，进入 || 分支处理
git rebase upstream/mainline || true

# 循环处理，直到 rebase 状态目录消失（应对多提交连续冲突的情况）
while [ -d "$(git rev-parse --git-path rebase-merge)" ] || [ -d "$(git rev-parse --git-path rebase-apply)" ]; do
    # 清理上游已删除（UD）的冲突文件
    git status --porcelain | awk '$1 == "UD" {print $2}' | xargs -r git rm
    
    # 检查是否还残留其他类型的未解决冲突（如 UU、DU 等），防止 git add . 盲目覆盖真冲突
    if git status --porcelain | grep -qE '^(UU|AA|DD|AU|UA|DU)'; then
        echo "检测到其他类型的代码冲突，已暂停脚本，请手动解决后运行 git rebase --continue"
        exit 1
    fi

    git add .
    # 跳过提交信息编辑器弹窗，直接沿用原 commit message 继续
    GIT_EDITOR=true git rebase --continue
done
