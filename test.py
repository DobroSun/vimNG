#!/usr/bin/env python3

import queue
import sys
import subprocess
import tempfile
import threading as thr
import multiprocessing as mpr

class CallerThread(mpr.Process):
    def __init__(self, work_q, lock):
        super().__init__()
        self.work_q = work_q
        self.lock = lock

    def run(self):
        proc = subprocess.Popen(["find * -type f"], shell=True, stdout=subprocess.PIPE)
        filenames = proc.communicate()[0].decode().split("\n")
        
        print("Before waiting", filenames)

        th = thr.Thread(target=lambda proc: proc.wait(), args=(proc,))
        th.start()

        
        for file in filenames:
            if file == "":
                continue
            self.work_q.put(file)

        running_workers = []
        nthreads = len(filenames) if len(filenames) < 17 else 16
        print(nthreads)
        for i in range(nthreads):
            th = WorkerThread(self.lock, self.work_q)
            th.start()

class WorkerThread(mpr.Process):
    def __init__(self, lock, work_q):
        super().__init__()
        self.lock = lock
        self.work_q = work_q
        self._running = True

    def run(self):
        while self._running:
            try:
                task = self.work_q.get_nowait()
                
                print("Semo")
                # parse file and push to with self.lock: database

                #self.work_q.task_done()
            except queue.Empty:
                print("Terminating")
                self.terminate()
    
    def terminate(self):
        self._running = False

def main():
    #tmp_db = tempfile.NamedTemporaryFile(suffix=".db")
    #f = open("w.db")
    lock = mpr.Lock()
    work_q = mpr.Queue()


    caller = CallerThread(work_q, lock)
    caller.start()


    #tmp_db.close()

if __name__ == "__main__":
    prc = mpr.Process(target=main, args=())
    prc.start()

    a = 1
    for i in range(10):
        a += a * a
        print(a)
