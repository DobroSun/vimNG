"echo libcall("/vim_scan/main_vim.so", "main", 3)

function! vim_scan#Hello()
    echo "Hello world"
endfunction

nnoremap <C-k> :call vim_scan#Hello()<CR>
echo "Another"
