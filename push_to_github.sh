#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
REPO_URL="${1:-git@github.com:gonz-mart/franc-tireur.git}"

git config core.sshCommand "ssh -i /home/jovyan/.ssh/github_no_pass -o StrictHostKeyChecking=no"
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REPO_URL"
else
  git remote add origin "$REPO_URL"
fi

echo "Pushing main branch and v1.0.0-cefr-b1 tag to $REPO_URL ..."
git tag -f v1.0.0-cefr-b1
git push -u origin main --tags
echo "Done! GitHub Actions is now building Web (GitHub Pages), Windows, Linux, and macOS releases."
