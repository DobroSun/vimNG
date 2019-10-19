function! s:start()
    new tmp 
    while g:is_input
        redraw
        let s:char = getchar()
        call s:set_bindings()

        let s:p_c = (!type(s:char))? nr2char(s:char): s:char
        let s:str .= s:p_c
        call setline('.', s:str)
    endwhile
endfunction

function! s:set_bindings(char)
    if a:char == "\<BS>"
        if strlen(s:str) == 1
            let s:str = ''
        endif
        let s:str = s:str[:-2]
        let s:char = ''
    elseif nr2char(s:char) == "\<CR>"
        let g:is_input = 0
        let a:char = ''
    endif
endfunction

function! s:todo(char)
    if a:char == "\<BS>"
        return 1
    elseif a:char == "\<C-H>"
        return 2
    return 0
    endif

endfunction

function! s:write()
endfunction

function! s:close()
endfunction

function! vim_scan#start_python()
if !g:is_running
    let g:is_runnging = 1
    call s:close()
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

# Переделывать все через питоновский класс,
# Главный поток будет брать Символы у user и отправлять в очередь,
# Дочерний поток должен брать из очереди данные grep их затем отправляя главному потоку из
# другой очереди.
# Только главный поток будет рисовать на окне в текущем буфере.
# Дочерние потоки будут парсить каталоги на наличие введенного объекта.

class Buffer():
    def __init__(self, lock, buf_q, send_q):
        self.buf_q = buf_q
        self.send_q = send_q
        self.lock = lock

    def write(self, msg=0, *, header=False):
        curbuf = vim.current.buffer

        if header:
            curbuf[0] = msg
        else:
            curbuf.append(msg)

    def redraw(self):
        with self.lock:
            vim.command("redraw")

    def set_bindings(self, char):
        if char == "13":
            return 0, ''
        vim.command("let s:char = %s" % char)
        return 1, vim.eval("nr2char(s:char)")

class HandlerThread(thr.Thread):
    def __init__(self, buf_q, send_q):
        super().__init__()
        self.buf_q = buf_q
        self.send_q = send_q
        self._running = True

    def run(self):
        while self._running:
            if not self.send_q.empty():
                item = self.send_q.get()
                # request to database
                item = "Hello"
                self.buf_q.put(item)

    def terminate(self):
        self._running = False

class RefreshThread(thr.Thread):
    def __init__(self, lock):
        super().__init__()
        self.lock()
        self._running = True

    def run(self):
        pass

    def terminate(self):
        self._running = False

def main():
    # Global variables

    is_running = vim.eval("g:is_running")
    string = vim.eval("s:str")
    string = ''
    buf_q, send_q = queue.Queue(), queue.Queue()
    lock = thr.Lock()
    buf = Buffer(lock, buf_q, send_q)

    # Thread that starts parsing threads
    # And put in work_q files to search
    # Than threads will get files from worq_q and
    # fill database with parsed text

    # Actual window
    vim.command("new tmp")

    #handler = HandlerThread(buf_q, send_q)
    #handler.start()


    while is_running:
        buf.redraw()
        if not buf.buf_q.empty():
            msg = buf.buf_q.get()
            buf.write(msg)

        # <C-c> gonna ruin all
        # Не может use С-с и BS
        vim.command("execute 'try | let s:char = getchar() | catch | endtry'")

        vim.command("let s:num = s:todo(s:char)")
        todo = vim.eval("s:num")
        print(todo)
        #string += input
        buf.send_q.put(string)
        buf.write(string, header=True)
    #handler.terminate()
    # call new mode in buffer to navigate written text
    # to change to new file
main()
EOF
endfunction

let g:is_running = 1
let s:str = ''
nnoremap <C-k> :call vim_scan#start_python()<CR>
