# vimNG
Script to navigate between files for vim

# Install
```sh
curl -fLo ~/.vim/autoload/vimNG.vim --create-dirs \
        https://raw.githubusercontent.com/DobroSun/vimNG/master/vimNG.vim
```
And put this to your .vimrc file:
```vim
nnoremap <C-k> :call vimNG#begin()<CR>
```

# Notes
-----
* 1:
When script parses current and sub-directories it takes all files(including binary)
To avoid that it will parse your .gitignore file and exclude matched files
* 2:
Script only works for root user(Why?)
