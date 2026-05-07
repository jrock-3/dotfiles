# dotfiles

Personal dev environment config (Zsh, Neovim, Tmux, etc.).

## Git push

`git push` is always blocked by the sandbox (GitHub is not on the allowlist).
Never attempt `git push` — instead pipe the command to clipboard:

```
echo "cd ~/git-repos/dotfiles && git push" | pbcopy
```

Then tell the user the command is copied and they can run it manually.
