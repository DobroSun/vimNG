let s:ok = 0
function! s:start()
    new tmp

    let g:is_input = 1
    let s:str = ''
    while g:is_input
        redraw
        let s:char = getchar()
        call s:set_bindings()

        let s:p_c = (!type(s:char))? nr2char(s:char): s:char
        let s:str .= s:p_c
        call setline('.', s:str)
    endwhile
endfunction

function! s:set_bindings()
    if s:char == "\<BS>"
        if strlen(s:str) == 1
            let s:str = ''
        endif
        let s:str = s:str[:-2]
        let s:char = ''
    elseif nr2char(s:char) == "\<CR>"
        let g:ok = 1
        let g:is_input = 0
        let s:char = ''
    endif
endfunction

function! s:write()
    while 1
        sleep(2)
        echo "Doing nothing"
    endwhile
endfunction

function! s:close()
    "echo "Closing"
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
    vim.command("call s:start()")

def write_func():
    vim.command("call s:write()")

def main():
    write_th = thr.Thread(target=write_func, args = ())
    write_th.start()
    write_th.join()
    read_func()
    #read_th = thr.Thread(target=read_func, args = ())

main()
EOF
endfunction

let g:is_running = 1
nnoremap <C-k> :call vim_scan#start_python()<CR>
"nnoremap <C-c> :call s:close()<CR>
