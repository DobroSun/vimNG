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

function! s:todo(char, string, is_running)
    let s:string = a:string
    let s:char = a:char
    let s:is_running = a:is_running
    if a:char == "\<BS>"
        let s:string = (strlen(s:string) > 1)? s:string[:-2]: ''
        let s:char = ''
    elseif nr2char(a:char) == "\<CR>"
        let s:is_running = 0
        let s:char = ''
    endif
    let s:string .= nr2char(s:char)

    return [s:string, s:is_running]
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
        self.lock = lock
        self.buf_q = buf_q
        self.send_q = send_q

    def write(self, msg=0, *, header=False):
        curbuf = vim.current.buffer

        if header:
            curbuf[0] = msg
        else:
            curbuf.append(msg)

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

class HandlerThread(thr.Thread):
    def __init__(self, lock, buf_q, send_q):
        super().__init__()
        self.lock = lock
        self.buf_q = buf_q
        self.send_q = send_q
        self._running = True

    def run(self):
        while self._running:
            if not self.send_q.empty():
                item = self.send_q.get()
                # with self.lock:
                    # request to database
                item = "Hello"
                self.buf_q.put(item)

    def terminate(self):
        self._running = False

class CallerThread(thr.Thread):
    def __init__(self, work_q, lock, tmp_db):
        super().__init__()
        self.work_q = work_q
        self.lock = lock
        self.tmp_db = tmp_db

    def run(self):
        filenames = subprocess.Popen(["find * -type f"], shell=True, stdout=subprocess.PIPE).communicate()[0].decode().split("\n")
        
        for file in filenames:
            self.work_q.put(file)

        running_workers = []
        nthreads = len(output) if len(output) < 17 else 16
        for i in range(nthreads):
            th = WorkerThread(self.lock, self.work_q, tmp_db)
            th.start()

class WorkerThread(thr.Thread):
    def __init__(self, lock, work_q, tmp_db):
        super().__init__()
        self.lock = lock
        self.work_q = work_q
        self.tmp_db = tmp_db
        self._running = True

    def run(self):
        while self._running:
            try:
                task = self.work_q.get()
                
                # parse file and push to with self.lock: database

                worq_q.task_done()
            except queue.Empty():
                self.terminate()
    
    def terminate(self):
        self._running = False

class RefreshThread(thr.Thread):
    def __init__(self, lock):
        super().__init__()
        self.lock()
        self._running = True

    def run(self):
        while self._running:
            with self.lock:
                vim.command("redraw")

    def terminate(self):
        self._running = False

def main():
    # Global variables

    is_running = vim.eval("g:is_running")

    string = ''
    buf_q, send_q = queue.Queue(), queue.Queue()
    buf_lock, db_lock = thr.Lock(), thr.Lock()
    buf = Buffer(buf_lock, buf_q, send_q)

    #tmp_db = tempfile.NamedTemporaryFile(suffix=".db")


    # Call workerThreads to 
    #caller = CallerThread(work_q, db_lock, tmp_db)
    #caller.start()


    # Actual window
    vim.command("new tmp")

    # Call to database and put to buf_q
    handler = HandlerThread(db_lock, buf_q, send_q)
    handler.start()


    while is_running:
        buf.redraw()
        if not buf.buf_q.empty():
            # Writes from buf_q
            msg = buf.buf_q.get()
            buf.write(msg)

        string, is_running = buf.handle_input(string, is_running)

        # Send on handling
        buf.send_q.put(string)
        buf.write(string, header=True)
    handler.terminate()
    # call new mode in buffer to navigate written text
    # to change to new file
main()
EOF
endfunction

let g:is_running = 1
let s:str = ''
nnoremap <C-k> :call vim_scan#start_python()<CR>
