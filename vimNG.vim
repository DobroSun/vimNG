function! vimNG#begin()
    call vimNG#init_globals()

    " Initialize all parsers
    call vimNG#main()

    new input

    let s:str = ''
    let g:is_input = 1
    while g:is_input
        redraw
        let s:char = getchar()
        let s:str = s:handle_input(s:str, s:char)

        let s:answer = s:make_request_to_db(s:str)

        call s:write_to_buf(s:str, 0)
        if !empty(s:answer)
            call s:write_to_buf(s:answer, 1)
        endif
    endwhile

    set nomodifiable
    set modifiable
endfunction

function! s:handle_input(str, char)
    if a:char == "\<BS>"
        return (strlen(a:str) > 1)? a:str[:-2]: ''
    elseif nr2char(a:char) == "\<CR>"
        let g:is_input = 0
        return a:str
    endif
    return s:str . nr2char(s:char)
endfunction

function! s:write_to_buf(str, line)
let py_exe = 'python3'
execute py_exe "<< EOF"
msg = vim.eval("a:str")
line = int(vim.eval("a:line"))
buf.write(msg, line)
EOF
endfunction

function! s:make_request_to_db(str)
let py_exe = 'python3'
execute py_exe "<< EOF"
request = vim.eval("a:str")
send_q.put(request)

answer = ["Hello", "World"]
vim.command("let s:answer = py3eval('answer')")
#answer = buf_q.get()
EOF
return s:answer
endfunction

function! vimNG#init_globals()
let s:char = ''
let py_exe = 'python3'
execute py_exe "<< EOF"
import datetime
import sqlite3
import functools
import os
import sys
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

class Buffer():
    def __init__(self, lock, buf_q, send_q):
        self.lock = lock
        self.buf_q = buf_q
        self.send_q = send_q

    def write(self, msg, line):
        curbuf = vim.current.buffer

        if not line:
            curbuf[line] = msg
        else:
            for i, row in enumerate(answer):
                try:
                    curbuf[i+1] = row
                except:
                    curbuf.append(row)

    def redraw(self):
        with self.lock:
            vim.command("redraw")

    def handle_input(self, string, is_running):
        vim.command("execute 'try | let s:char = getchar() | catch | endtry'")

        vim.command("let s:string = '%s'" % string)
        vim.command("let s:is_running = '%s'" % is_running)

        vim.command("let s:list = s:todo(s:char, s:string, s:is_running)")
        string = vim.eval("get(s:list, 0)")
        is_running = int(vim.eval("get(s:list, 1)"))

        return string, is_running

buf_lock = thr.Lock()
buf_q, send_q, work_q = queue.Queue(), queue.Queue(), queue.Queue()
buf = Buffer(buf_lock, buf_q, send_q)
EOF
endfunction



function! vimNG#main()
let py_exe = 'python3'
execute py_exe "<< EOF"

class RefreshThread(thr.Thread):
    def __init__(self, lock):
        super().__init__()
        self.lock = lock
        self._running = True

    def run(self):
        while self._running:
            with self.lock:
                vim.command("redraw")

    def terminate(self):
        self._running = False
EOF
endfunction

nnoremap <C-k> :call vimNG#begin()<CR>
