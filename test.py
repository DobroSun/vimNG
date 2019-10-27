#!/usr/bin/env python3

import sys
import queue
import sys
import os
import re
import sqlite3
import sys
import subprocess
import tempfile
import threading as thr
#import multiprocessing as mp

class HandlerThread(thr.Thread):
    def __init__(self, buf_q, send_q, tmp_db):
        super().__init__()
        self.buf_q = buf_q
        self.send_q = send_q
        self.tmp_db = tmp_db
        self._running = True

    def run(self):
        while self._running:
            # Will wait for any object in queue
            name = self.send_q.get()


            msg = self.get_from_db(name)
            print(msg, " <- Message from db\n")
            self.buf_q.put(msg)

    def get_from_db(self, name):
        conn = sqlite3.connect(self.tmp_db.name)
        cursor = conn.cursor()

        answer = []
        for row in cursor.execute(f"""SELECT * FROM defs WHERE row LIKE '%{name}%'"""):
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

        print("Before waiting", filenames, sep=": ")
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
        print("Terminating")
        self._running = False
        if self.conn:
            self.conn.close()

def main():
    db_lock = thr.Lock()
    work_q, buf_q, send_q = queue.Queue(), queue.Queue(), queue.Queue()
    tmp_db = tempfile.NamedTemporaryFile(suffix=".db")
    for i in ['pyjlskdjfklsdjf;lkdajs']:
        send_q.put(i)

    def init_db():
        conn = sqlite3.connect(tmp_db.name)
        cursor = conn.cursor()

        cursor.execute("""CREATE TABLE IF NOT EXISTS defs (filename text, line int, row text)""")

        conn.commit()
        conn.close()
    init_db()


    caller = CallerThread(work_q, db_lock, tmp_db)
    caller.start()

    caller.join()
    
    h = HandlerThread(buf_q, send_q, tmp_db)
    #h.daemon = True
    h.start()

    def print_db():
        conn = sqlite3.connect(tmp_db.name)
        cursor = conn.cursor()

        for row in cursor.execute("""SELECT * FROM defs"""):
            print(row)

        conn.close()
    #print_db()

if __name__ == "__main__":
    prc = thr.Thread(target=main, args=())
    prc.start()
