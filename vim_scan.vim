

function! Read()
    new tmp

    let s:str = ''
    while 1
        redraw
        let s:char = getchar()

        if s:char == "\<BS>"
            let s:str = s:str[:(strchars(s:str) - 2)]
            let s:char = ''
        endif

        let s:str = s:str . nr2char(s:char)
        call setline('.', s:str)
    endwhile
endfunction

function! Write()
    while 1
        let s:res = getline('0')
        "call system("grep -R" . s:res)
        call append('$', 'Hello world')
    endwhile
endfunction

function! vim_scan#update_python()
let py_exe = has('python') ? 'python' : 'python3'
execute py_exe "<< EOF"
import datetime
import functools
import os
try:
    import queue
except ImportError:
    import Queue as queue
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
    vim.command("call Read()")

def write_func():
    vim.command("call Write()")

def main():
    read_func()
    write_th = thr.Thread(target=write_func, args = ())
    #read_th = thr.Thread(target=read_func, args = ())

main()
endfunction

nnoremap <C-k> :call vim_scan#update_python()<CR>
