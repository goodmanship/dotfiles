#!/bin/bash
file=~/.config/ghostty/epl-teams.txt
count=$(wc -l < "$file" | tr -d ' ')
line=$((RANDOM % count + 1))
title=$(sed -n "${line}p" "$file")
printf '\e]2;%s\e\\' "$title"
exec zsh -l
