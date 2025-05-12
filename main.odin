package main

import "core:log"
import "core:time"
import "core:sync"
import "core:thread"
import "core:math/rand"

TaskType :: enum {
	EASY,
	MEDIUM,
	HARD,
}

Task :: struct {
	id: u32,
	type: TaskType,
	time: i64,
}

@(rodata)
WORKERS := 2

pool_lock: sync.Mutex
pool_sema: sync.Sema

worker :: proc(pool: ^[dynamic]Task) {
	defer sync.sema_post(&pool_sema)
	context.logger = log.create_console_logger()
	
	sync.mutex_lock(&pool_lock)
	if len(pool) == 0 {
		sync.mutex_unlock(&pool_lock)
		return
	}
	task := pop(pool)
	sync.mutex_unlock(&pool_lock)

	log.infof("Scheduling: %d of type %d", task.id, task.type)
	time.sleep(time.Duration(task.time * 1000000000))
	log.infof("Done: %d", task.id)
}

main :: proc() {
	context.logger = log.create_console_logger()

	now := time._now()
	state := rand.create(u64(now._nsec))
	generator := rand.default_random_generator(&state)
	
	tasks_number := (rand.uint32(generator) % 10) + 10
	tasks := make([dynamic]Task, tasks_number, tasks_number)
	defer delete(tasks)
	for i in 0..<tasks_number {
		tasks[i] = Task{
			id = i,
			type = rand.choice_enum(TaskType, generator),
			time = i64((rand.uint32(generator) % 10) + 1),
		}
	}

	rand.shuffle(tasks[:], generator)
	sync.sema_post(&pool_sema, WORKERS)
	done := 0
	log.info("Starting")
	for done != WORKERS {
		sync.mutex_lock(&pool_lock)
		length := len(tasks)
		sync.mutex_unlock(&pool_lock)

		if length == 0 {
			sync.sema_wait(&pool_sema)
			done += 1
			continue
		}

		sync.sema_wait(&pool_sema)
		thread.create_and_start_with_poly_data(&tasks, worker)
	}

	log.info("Done")
}
