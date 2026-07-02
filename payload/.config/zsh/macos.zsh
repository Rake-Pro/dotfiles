# macOS-only aliases/config
alias flushdns="sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
alias showfiles="defaults write com.apple.finder AppleShowAllFiles YES && killall Finder"
alias hidefiles="defaults write com.apple.finder AppleShowAllFiles NO && killall Finder"
alias o="open ."

# Homebrew shellenv, if present (Apple Silicon path)
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
