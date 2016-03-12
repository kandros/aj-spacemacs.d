#!/usr/bin/env bash

[[ -d ~/.spacemacs.d/layers/+TheBB ]] || \
    git clone git@github.com:TheBB/spacemacs-layers.git ~/.spacemacs.d/layers/+TheBB

[[ -d ~/.spacemacs.d/layers/+justbur ]] || \
    git clone git@github.com:justbur/spacemacs-layers.git ~/.spacemacs.d/layers/+justbur

# Disable app nap for emacs so it doesn't cause terrible difficult to track down
# things to happen https://github.com/syl20bnr/spacemacs/issues/5413
defaults write org.gnu.Emacs NSAppSleepDisabled -bool YES
