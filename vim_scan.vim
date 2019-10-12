
function! Start()
   new tmp

    let g:is_input = 1
    let s:str = ''
    while g:is_input
        redraw
        let s:char = getchar()
        "let s:s = nr2char(s:char)
        "let s:s = s:char
        let g:is_input = Set_Bindings()

        let s:p_c = (!type(s:char))? nr2char(s:char): s:char
        let s:str = s:str . s:p_c
        call setline('.', s:str)
    endwhile
endfunction

function! Set_Bindings()
    "echo type(s:char)
    echo nr2char(s:char)

    if s:char == "\<BS>"
        if strlen(s:str) == 1
            let s:str = ''
        endif
        let s:str = s:str[:-2]
        let s:char = ''
    elseif nr2char(s:char) == "\<CR>"
        let g:is_input = 0
        let s:char = ''
    endif
    return g:is_input
endfunction

function! Write()
    while 1
        let s:res = getline('0')
        "call system("grep -R" . s:res)
        call append('$', 'Hello world')
    endwhile
endfunction

function! Close()
    echo "Closing"
endfunction

function! vim_scan#start_python()
if !g:is_running
    let g:is_runnging = 1
    call Close()
endif
let g:is_runnging = 0

let py_exe = 'python3'
execute py_exe "<< EOF"
import datetime
import functools
import os
import queue
import random
import re
import shutil
import signal
import subprocess
import tempfile
import threading as thr
import time
import traceback
import vim

def read_func():
    vim.command("call Start()")

def write_func():
    vim.command("call Write()")

def main():

    read_func()
    write_th = thr.Thread(target=write_func, args = ())
    #read_th = thr.Thread(target=read_func, args = ())

main()
EOF
endfunction

let g:is_running = 1
nnoremap <C-k> :call vim_scan#start_python()<CR>
