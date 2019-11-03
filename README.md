# vimNG
-----
Vim script to navigate between files in project

# Install
-----
```sh
curl -fLo ~/.vim/autoload/vimNG.vim --create-dirs \
        https://raw.githubusercontent.com/DobroSun/vimNG/master/vimNG.vim
```
And put this to your .vimrc file:
```vim
nnoremap <C-k> :call vimNG#begin()<CR>
```

# Notes
* Script only works for root user(Why?)

# TODO
1) Fix bunch of bugs
