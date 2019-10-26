#!/usr/bin/env python3

import queue
import re
import sqlite3
import sys
import subprocess
import tempfile
import threading as thr
import multiprocessing as mp

class CallerThread(thr.Thread):
    def __init__(self, work_q, lock):
        super().__init__()
        self.work_q = work_q
        self.lock = lock


    def run(self):
        proc = subprocess.Popen(["find * -type f"], shell=True, stdout=subprocess.PIPE)
        filenames = proc.communicate()[0].decode().split("\n")
        
        print("Before waiting", filenames, sep=": ")

        th = thr.Thread(target=lambda proc: proc.wait(), args=(proc,))
        
        for file in filenames:
            if file == "" or file == DB_NAME:
                continue
            self.work_q.put(file)

        running_workers = []
        nthreads = len(filenames) if len(filenames) < 17 else 16
        nthreads = 1
        for i in range(nthreads):
            th = WorkerThread(self.lock, self.work_q)
            th.start()

class WorkerThread(thr.Thread):
    PY_RE = [r".* = .*", r"def \w*(.*):", r"class \w*(.*):"]

    def __init__(self, lock, work_q):
        super().__init__()
        self.lock = lock
        self.work_q = work_q
        self._running = True
        self.connected = False
        self.conn = self.cursor = None

    def parse_file(self, filename):
        with open(filename, "r") as f:
            for i, line in enumerate(f.read().split("\n")):
                for pattern in self.PY_RE:
                    compiled_p = re.compile(pattern)
                    res = re.search(compiled_p, line)
                    if not res:
                        continue
                    #print(i, res.group(0), sep="    ")
                    self.push_to_db((filename, i, res.group(0)))

    def push_to_db(self, values):
        def _create_conn():
            self.conn = sqlite3.connect(DB_NAME)
            self.cursor = self.conn.cursor()

        if not self.connected:
            _create_conn()
            self.connected = True
        sql = """INSERT INTO defs VALUES (?, ?, ?)"""
        #print(*values, sep="  ")
        self.cursor.executemany(sql, [values])
        with self.lock:
            self.conn.commit()

    def run(self):
        while self._running:
            try:
                task = self.work_q.get_nowait()
                
                #print("Semo")
                self.parse_file(task)
                # parse file and push to with self.lock: database

                #self.work_q.task_done()
            except queue.Empty:
                print("Terminating")
                self.terminate()
    
    def terminate(self):
        self._running = False

DB_NAME = "w.db"

def print_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    sql = """SELECT * FROM defs"""
    for row in cursor.execute(sql):
        print(row)

def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    def del_all_in_db(conn, cursor):
        try:
            sql = """DROP TABLE defs"""
            cursor.execute(sql)
        except:
            pass

    del_all_in_db(conn, cursor)

    sql = """CREATE TABLE defs
                (filename text, line int, row text)"""
    try:
        cursor.execute(sql)
    except:
        pass


def main():
    #tmp_db = tempfile.NamedTemporaryFile(suffix=".db")
    #f = open("w.db")
    lock = mp.Lock()
    work_q = mp.Queue()

    conn = sqlite3.connect(DB_NAME)

    caller = CallerThread(work_q, lock)
    caller.start()

    #tmp_db.close()

if __name__ == "__main__":
    init_db()
    prc = thr.Thread(target=main, args=())
    prc.start()

    a = 1
    for i in range(10):
        a += a * a

    prc.join()
    print_db()
    print("END")
