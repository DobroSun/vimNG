function! vimNG#begin()    
    enew
    echo "Search for definitions"

    let s:str = ''
    let g:is_input = 1
    let g:choosing = 1
    while g:is_input
        redraw
        let s:char = getchar()
        let s:str = s:handle_input(s:str, s:char)

        if !g:is_input
            break
        endif

        let s:answer = s:make_request_to_db(s:str)

        call s:write_to_buf(s:str, 0)
        call s:write_to_buf(s:answer, 1)
    endwhile
    call s:join_all()

    set cursorline
    
    normal! 2G
    let s:curline = '2'
    while g:choosing
        let s:char = getchar()

        let s:curline = s:handle_cursor_pos(s:char, s:curline)

        silent! execute '/\%' . s:curline . 'l\%>0c./'
        redraw
    endwhile
    "call s:close_db()

    let s:string = getline(s:curline)
    let [s:filename, s:line] = s:compute_file(s:string)

    bdelete!
    execute 'edit +' . s:line . " " . s:filename
    set nocursorline
    call s:re_init()
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
str_ans = ["{0}: {1}: {2}".format(*i) for i in answer]
vim.command("let s:answer = py3eval('str_ans')")
EOF
return s:answer
endfunction

function! s:handle_cursor_pos(char, line)
    let s:line = str2nr(a:line)
    if nr2char(a:char) == 'j'
        let s:line += 1 
    elseif nr2char(a:char) == 'k'
        let s:line -= 1 
    elseif nr2char(a:char) == "\<CR>"
        let g:choosing = 0
    endif
    return string(s:line)
endfunction

function! s:join_all()
let py_exe = 'python3'
execute py_exe "<< EOF"
prc.join()

h.terminate()
for t in refreshers:
    t.terminate()
EOF
endfunction

function! s:close_db()
let py_exe = 'python3'
execute py_exe "<< EOF"
tmp_db.close()
EOF
endfunction

function! s:compute_file(curline)
let py_exe = 'python3'
execute py_exe "<< EOF"
str = vim.eval("a:curline")
attr = re.findall(r'((.*/)?\w*\.\w*): (\d+): (.*)', str)

# WTF?
name = attr[0][0]
line = attr[0][2]

vim.command("let s:filename = py3eval('name')")
vim.command("let s:line = py3eval('line')")
EOF
return [s:filename, s:line]
endfunction

function! s:re_init()
    call vimNG#init_globals()
    call vimNG#parse()
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

class HandlerThread(thr.Thread):
    def __init__(self, buf_q, send_q, lock, tmp_db):
        super().__init__()
        self.buf_q = buf_q
        self.send_q = send_q
        self.lock = lock
        self.tmp_db = tmp_db
        self.connected = False
        self._running = True
        self.conn = None
        self.cursor = None

    def run(self):
        while self._running:
            # Will wait for any object in queue
            name = self.send_q.get()

            msg = self.get_from_db(name)
            self.buf_q.put(msg)

    def get_from_db(self, name):
        def _create_conn():
            self.conn = sqlite3.connect(self.tmp_db.name)
            self.cursor = self.conn.cursor()

        if not self.connected:
            _create_conn()
            self.connected = True
        answer = []
        with self.lock:
            response = self.cursor.execute(f"""SELECT * FROM defs WHERE row LIKE '%{name}%'""")
        for row in response:
            answer.append(row)
        return answer

    def terminate(self):
        self._running = False


buf_lock, db_lock = thr.Lock(), thr.Lock()
buf_q, send_q, work_q = queue.Queue(), queue.Queue(), queue.Queue()
tmp_db = tempfile.NamedTemporaryFile(suffix=".db")
refreshers = []
buf = Buffer(buf_lock, buf_q, send_q)
h = HandlerThread(buf_q, send_q, db_lock, tmp_db)

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
                vim.command("redraw")
            time.sleep(0.33)

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
    can_parse = {".py", ".cpp"}
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
        file_ext = re.findall(r"\.\w*$", filename)
        if len(file_ext) != 1 or file_ext[0] not in self.can_parse:
            return 

        parsed_lines = []
        with open(filename, "r") as f:
            for i, line in enumerate(f.read().split("\n")):
                for pattern in self.PY_RE:
                    res = re.search(pattern, line)
                    if not res or res.start() not in [0, 4]:
                        continue
                    parsed_lines.append((filename, i+1, res.group(0)))
        return parsed_lines

    def push_to_db(self, values):
        if not values:
            return

        def _create_conn():
            self.conn = sqlite3.connect(self.tmp_db.name)
            self.cursor = self.conn.cursor()

        if not self.connected:
            _create_conn()
            self.connected = True

        with self.lock:
            self.cursor.executemany("""INSERT INTO defs VALUES (?, ?, ?)""", values)
            self.conn.commit()

    def run(self):
        while self._running:
            task = self.work_q.get()
            if task is None:
                self.terminate()
                continue

            parsed_lines = self.parse_file(task)
            self.push_to_db(parsed_lines)

            self.work_q.task_done()
    
    def terminate(self):
        self._running = False
        if self.conn:
            self.conn.close()

def main(h):
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

    #h = HandlerThread(buf_q, send_q, db_lock, tmp_db)
    h.daemon = True
    h.start()

    caller = CallerThread(work_q, db_lock, tmp_db)
    caller.start()
    caller.join()


prc = thr.Thread(target=main, args=(h,))
prc.start()
EOF
endfunction

augroup closing_tmp_db
    autocmd!
    autocmd VimLeave * :call s:close_db()

    " If all workers aren't terminated it's impossible to quit vim
    autocmd VimLeave * :call s:join_all()
augroup END

call vimNG#init_globals()
call vimNG#parse()

nnoremap <C-k> :call vimNG#begin()<CR>
