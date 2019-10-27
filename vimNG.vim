function! vimNG#begin()    
    enew

    let s:str = ''
    let g:is_input = 1
    while g:is_input
        redraw
        let s:char = getchar()
        let s:str = s:handle_input(s:str, s:char)

        let s:answer = s:make_request_to_db(s:str)

        call s:write_to_buf(s:str, 0)
        call s:write_to_buf(s:answer, 1)
    endwhile

    "new mode
    call s:close_all()
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

answer = buf_q.get()
str_ans = ["{0}: line: {1}; {2}".format(*i) for i in answer]
vim.command("let s:answer = py3eval('str_ans')")
EOF
return s:answer
endfunction

function! s:close_all()
let py_exe = 'python3'
execute py_exe "<< EOF"
tmp_db.close()
for t in refreshers:
    t.join()
EOF
endfunction

function! vimNG#init_globals()
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
            for i in range(1, len(curbuf)):
                curbuf[i] = ''

            for i, row in enumerate(msg):
                try:
                    curbuf[i+1] = row
                except:
                    curbuf.append(row)

    def redraw(self):
        with self.lock:
            vim.command("redraw")

buf_lock, db_lock = thr.Lock(), thr.Lock()
buf_q, send_q, work_q = queue.Queue(), queue.Queue(), queue.Queue()
tmp_db = tempfile.NamedTemporaryFile(suffix=".db")
refreshers = []
buf = Buffer(buf_lock, buf_q, send_q)
EOF
endfunction

function! vimNG#parse()
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
                vim.command("noautocmd normal! a")
            time.sleep(0.33)    

    def terminate(self):
        self._running = False

class HandlerThread(thr.Thread):
    def __init__(self, buf_q, send_q, lock, tmp_db):
        super().__init__()
        self.buf_q = buf_q
        self.send_q = send_q
        self.lock = lock
        self.tmp_db = tmp_db
        self._running = True

    def run(self):
        while self._running:
            # Will wait for any object in queue
            name = self.send_q.get()

            msg = self.get_from_db(name)
            self.buf_q.put(msg)

    def get_from_db(self, name):
        conn = sqlite3.connect(self.tmp_db.name)
        cursor = conn.cursor()

        answer = []
        with self.lock:
            response = cursor.execute(f"""SELECT * FROM defs WHERE row LIKE '%{name}%'""")
        for row in response:
            answer.append(row)
        return answer

    def terminate(self):
        self._running = False

class CallerThread(thr.Thread):
    def __init__(self, work_q, lock, tmp_db):
        super().__init__()
        self.work_q = work_q
        self.lock = lock
        self.tmp_db = tmp_db
        self.threads = []


    def run(self):
        proc = subprocess.Popen(["find * -type f"], shell=True, stdout=subprocess.PIPE)
        filenames = proc.communicate()[0].decode().split("\n")

        self.exclude_ignored_files(filenames)

        th = thr.Thread(target=lambda proc: proc.wait(), args=(proc,))

        threads = []
        nthreads = len(filenames) if len(filenames) < 17 else 16
        for i in range(nthreads):
            th = WorkerThread(self.lock, self.work_q, self.tmp_db)
            th.start()
            threads.append(th)

        for file in filenames:
            self.work_q.put(file)

        self.work_q.join()

        for i in range(nthreads):
            self.work_q.put(None)

        for t in threads:
            t.join()

    def exclude_ignored_files(self, filenames):
        ignored = ".gitignore"
        if not os.path.isfile(ignored):
            return

        filenames.remove('')
        with open(ignored) as f:
            ff = f.read().split("\n")
            ff.append(self.tmp_db.name)
            for pattern in ff:
                if pattern == '':
                    continue
                for file in filenames:
                    if re.search(pattern, file):
                        try:
                            filenames.remove(file)
                        except:
                            pass

class WorkerThread(thr.Thread):
    PY_RE = [r"\w* = .*", r"def \w*(.*):", r"class \w*(.*):"]

    def __init__(self, lock, work_q, tmp_db):
        super().__init__()
        self.lock = lock
        self.work_q = work_q
        self.tmp_db = tmp_db
        self._running = True
        self.connected = False
        self.conn = None
        self.cursor = None

    def parse_file(self, filename):
        with open(filename, "r") as f:
            for i, line in enumerate(f.read().split("\n")):
                for pattern in self.PY_RE:
                    compiled_p = re.compile(pattern)
                    res = re.search(compiled_p, line)
                    if not res or res.start() not in [0, 4]:
                        continue

                    self.push_to_db((filename, i+1, res.group(0)))

    def push_to_db(self, values):
        def _create_conn():
            self.conn = sqlite3.connect(self.tmp_db.name)
            self.cursor = self.conn.cursor()

        if not self.connected:
            _create_conn()
            self.connected = True

        self.cursor.executemany("""INSERT INTO defs VALUES (?, ?, ?)""", [values])
        with self.lock:
            self.conn.commit()

    def run(self):
        while self._running:
            task = self.work_q.get()
            if task is None:
                self.terminate()
                continue

            self.parse_file(task)
            self.work_q.task_done()
    
    def terminate(self):
        self._running = False
        if self.conn:
            self.conn.close()

def main():
    def init_db():
        conn = sqlite3.connect(tmp_db.name)
        cursor = conn.cursor()

        cursor.execute("""CREATE TABLE IF NOT EXISTS defs (filename text, line int, row text)""")

        conn.commit()
        conn.close()
    init_db()

    for i in range(4):
        refr = RefreshThread(buf_lock)
        refr.start()
        refreshers.append(refr)

    h = HandlerThread(buf_q, send_q, db_lock, tmp_db)
    h.daemon = True
    h.start()

    caller = CallerThread(work_q, db_lock, tmp_db)
    caller.start()
    caller.join()


prc = thr.Thread(target=main, args=())
prc.start()
EOF
endfunction

call vimNG#init_globals()
call vimNG#parse()
    
nnoremap <C-k> :call vimNG#begin()<CR>
