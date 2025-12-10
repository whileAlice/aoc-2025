/* I think this could be definitely improved, both with respect
   to the algorithm itself, and to better distribution of work
   over multiple cores. */
import std::collections::map;
import std::collections::list;
import std::collections::ringbuffer;
import std::core::string;
import std::io;
import std::io::file;
import std::os;
import std::time;
import std::thread;

import libc;

const INPUT_PATH       = "day_2_input.txt";
const THREAD_COUNT     = 4;
const ENABLE_PROFILING = true;

fn int first_task_thread(void* arg)
{
	Time thread_start = time::now();

	Payload* p = arg;

	StatsNode* sn = malloc(StatsNode.sizeof);
	sn.stats.init(mem);

	add_stat(&sn.stats, "[t1] stats init", thread_start);

	@in_lock(p.queue)
	{
		sn.id = p.queue.ready_count;
		p.queue.ready_count += 1;
		io::printfn("[worker %d] [t1] ready count set to %d, broadcasting queue cond",
					sn.id, p.queue.ready_count);

		@broadcast(p.queue);

		add_stat(&sn.stats, "[t1] thread startup", thread_start);

		while (p.queue.ready_count < THREAD_COUNT + 1) {
			io::printfn("[worker %d] [t1] waiting...", sn.id);

			@wait(p.queue);

			io::printfn("[worker %d] [t1] woken up", sn.id);
		}

		add_stat(&sn.stats, "[t1] thread wait", thread_start);
	};

	char[1024] buf;
	while (true) {
		Range? range;

		@in_lock(p.queue)
		{
			if (p.queue.ranges.written == 0) break;
			range = p.queue.ranges.pop();
		};

		if (catch err = range) {
			io::printfn("[t1] thread queue ranges pop: %s", err);
			os::exit(1);
		}

		for (ulong x = range.start; x <= range.end; ++x) {
			String num_str = string::bformat(&buf, "%d", x);
			libc::DivResult div_result = libc::div(num_str.len, 2);

			bool is_odd   = div_result.rem != 0;
			uint midpoint = div_result.quot;

			if (is_odd) continue;

			String part1 = num_str[..midpoint - 1];
			String part2 = num_str[midpoint..];

			if ((part1.to_uint()!!) == (part2.to_uint()!!)) {
				@in_lock(p.result)
				{
					p.result.value += x;
				};
			}
		}
	}

	add_stat(&sn.stats, "[t1] total_thread_time", thread_start);

	@in_lock(p.stats)
	{
		sn.next = p.stats.head;
		p.stats.head = sn;
	};

	io::printfn("[worker %d] [t1] thread returning", sn.id);

	return 0;
}

fn int second_task_thread(void* arg)
{
	Time thread_start = time::now();

	Payload* p = arg;

	StatsNode* sn = malloc(StatsNode.sizeof);
	sn.stats.init(mem);

	add_stat(&sn.stats, "[t2] stats init", thread_start);

	@in_lock(p.queue)
	{
		sn.id = p.queue.ready_count;
		p.queue.ready_count += 1;
		io::printfn("[worker %d] [t2] ready count set to %d, broadcasting queue cond",
					sn.id, p.queue.ready_count);

		@broadcast(p.queue);

		add_stat(&sn.stats, "[t2] thread startup", thread_start);

		while (p.queue.ready_count < THREAD_COUNT + 1) {
			io::printfn("[worker %d] [t2] waiting...", sn.id);

			@wait(p.queue);

			io::printfn("[worker %d] [t2] woken up", sn.id);
		}

		add_stat(&sn.stats, "[t2] thread wait", thread_start);
	};

	char[1024] buf;
	while (true) {
		Range? range;

		@in_lock(p.queue)
		{
			if (p.queue.ranges.written == 0) break;
			range = p.queue.ranges.pop();
		};

		if (catch err = range) {
			io::printfn("[t2] thread queue ranges pop: %s", err);
			os::exit(1);
		}

		// TODO: I think this could be optimized by noticing that subsequent numbers
		// don't differ much from previous ones, that only a difference of x digits
		// could possibly change the result compared to the previous number.
		ulong x = range.start;
		while RANGE: (x <= range.end) {
			defer ++x;

			Time processing_start = time::now();

			String num_str = string::bformat(&buf, "%d", x);

			uint div = 2;
			while DIV: (div <= num_str.len) {
				defer ++div;

				if (num_str.len % div != 0) continue;

				uint current_pos = 0;
				uint sub_num_len = num_str.len / div;
				while (current_pos < sub_num_len) {
					uint current_repetition = 1;
					while (current_repetition < div) {
						if (num_str[current_pos] !=
						    num_str[current_repetition * sub_num_len + current_pos]) {

							continue DIV;
						}

						current_repetition += 1;
					}

					current_pos += 1;
				}

				@in_lock(p.result)
				{
					p.result.value += x;
				};

				add_stat(&sn.stats, "[t2] processing_time (found)", processing_start);

				continue RANGE;
			}

		add_stat(&sn.stats, "[t2] processing_time (not found)", processing_start);
		}
	}

	add_stat(&sn.stats, "[t2] total_thread_time", thread_start);

	@in_lock(p.stats)
	{
		sn.next = p.stats.head;
		p.stats.head = sn;
	};

	io::printfn("[worker %d] [t2] thread returning", sn.id);

	return 0;
}

fn int main()
{
	Stats manager_stats;
	manager_stats.init(mem);

	Time main_start = time::now();

	String? raw_input = ((String)file::load_temp(INPUT_PATH));
	if (catch err = raw_input) {
		io::printfn("failed to open %s: %s", INPUT_PATH, err);

		os::exit(1);
	}
	String[] raw_ranges = raw_input.trim_right().tsplit(",");

	Ranges ranges;
	ranges.init();

	foreach (raw_range : raw_ranges) {
		String[] pair = raw_range.tsplit("-");
		ulong start   = pair[0].to_ulong()!!;
		ulong end     = pair[1].to_ulong()!!;

		ranges.push({ start = start, end = end });
	}

	add_stat(&manager_stats, "process_file", main_start);

	Time payload_1_init_start = time::now();

	Payload* payload_1 = tmalloc(Payload.sizeof);
	@cond_init(payload_1.queue);
	defer @cond_destroy(payload_1.queue);
	@mutex_init(payload_1.queue);
	defer @mutex_destroy(payload_1.queue);
	@mutex_init(payload_1.result);
	defer @mutex_destroy(payload_1.result);
	@mutex_init(payload_1.stats);
	defer @mutex_destroy(payload_1.stats);

	payload_1.queue.ranges = ranges;

	add_stat(&manager_stats, "payload_1_init", payload_1_init_start);

	Time task_1_thread_create_start = time::now();

	Thread[THREAD_COUNT] task_1_threads;
	foreach (i, &thread : task_1_threads) {
		if (catch err = thread.create(&first_task_thread, payload_1)) {
			io::printfn("task 1 thread %d create: %s", i, err);
		}
	}

	add_stat(&manager_stats, "create_task_1_threads", task_1_thread_create_start);

	Time wait_for_task_1_threads_start = time::now();

	@in_lock(payload_1.queue)
	{
		payload_1.queue.ready_count += 1;
		io::printfn("[manager] ready count set to %d", payload_1.queue.ready_count);

		@broadcast(payload_1.queue);
		io::printn("[manager] waking up threads");

		while (payload_1.queue.ready_count < THREAD_COUNT + 1) {
			io::printn("[manager] waiting for threads...");

			@wait(payload_1.queue);

			io::printn("[manager] woken up!");
		}
	};

	add_stat(&manager_stats, "waiting_for_task_1_threads",
			 wait_for_task_1_threads_start);

	io::printn("[manager] begin task 1");

	Time task_1_thread_join_start = time::now();

	foreach (i, &thread : task_1_threads) {
		io::printfn("task 1 joining thread %d", i);
		if (catch err = thread.join()) {
			io::printfn("task 1 thread %d join: %s", i, err);
		}
	}

	add_stat(&manager_stats, "task_1_thread_join", task_1_thread_join_start);

	io::printn("===============================================================");
	io::printfn("[result 1]: %d", payload_1.result.value);
	io::printn("===============================================================");

	Time payload_2_init_start = time::now();

	Payload* payload_2 = tmalloc(Payload.sizeof);
	@cond_init(payload_2.queue);
	defer @cond_destroy(payload_2.queue);
	@mutex_init(payload_2.queue);
	defer @mutex_destroy(payload_2.queue);
	@mutex_init(payload_2.result);
	defer @mutex_destroy(payload_2.result);
	@mutex_init(payload_2.stats);
	defer @mutex_destroy(payload_2.stats);

	payload_2.queue.ranges = ranges;

	add_stat(&manager_stats, "payload_2_init", payload_2_init_start);

	Time task_2_thread_create_start = time::now();

	Thread[THREAD_COUNT] task_2_threads;
	foreach (i, &thread : task_2_threads) {
		if (catch err = thread.create(&second_task_thread, payload_2)) {
			io::printfn("thread %d create: %s", i, err);
		}
	}

	add_stat(&manager_stats, "create_task_2_threads", task_2_thread_create_start);

	Time wait_for_task_2_threads_start = time::now();

	@in_lock(payload_2.queue)
	{
		payload_2.queue.ready_count += 1;
		io::printfn("[manager] ready count set to %d", payload_2.queue.ready_count);

		@broadcast(payload_2.queue);
		io::printn("[manager] waking up threads");

		while (payload_2.queue.ready_count < THREAD_COUNT + 1) {
			io::printn("[manager] waiting for threads...");

			@wait(payload_2.queue);

			io::printn("[manager] woken up!");
		}
	};

	add_stat(&manager_stats, "waiting_for_task_2_threads",
			 wait_for_task_2_threads_start);

	io::printn("[manager] begin task 2");

	Time task_2_thread_join_start = time::now();

	foreach (i, &thread : task_2_threads) {
		io::printfn("joining thread %d", i);
		if (catch err = thread.join()) {
			io::printfn("thread %d join: %s", i, err);
		}
	}

	add_stat(&manager_stats, "task_2_thread_join", task_2_thread_join_start);


	io::printn("===============================================================");
	io::printfn("[result 2]: %d", payload_2.result.value);
	io::printn("===============================================================");

	add_stat(&manager_stats, "total_main_time", main_start);

	if (!ENABLE_PROFILING) return 0;

	io::printn("===============================================================");
	io::printn("                           NICE STATS                          ");
	io::printn("===============================================================");
	Duration total_task_2_processing_time;
	Duration max_task_2_processing_time;

	while (payload_2.stats.head != null) {
		payload_2.stats.head.stats.@each(;String k, List{Duration} v) {
			if (k.contains("processing")) {
				total_task_2_processing_time += sum_durations(&v);
				if (max_task_2_processing_time < sum_durations(&v)) {
					max_task_2_processing_time = sum_durations(&v);
				}
			}

			io::printfn("[%d] %s: %s s", payload_2.stats.head.id,
						k, sum_durations(&v).to_nano().to_sec());
		};

		payload_2.stats.head = payload_2.stats.head.next;
	}
	io::printn("===============================================================");
	io::printfn("total t2 processing time: %s s",
				total_task_2_processing_time.to_nano().to_sec());
	io::printfn("max t2 processing time: %s s",
				max_task_2_processing_time.to_nano().to_sec());
	io::printfn("avg t2 processing time: %s s",
				total_task_2_processing_time.to_nano().to_sec() / THREAD_COUNT);
	io::printn("===============================================================");

	manager_stats.@each(;String k, List{Duration} v) {
		io::printfn("[main] %s: %s s", k, sum_durations(&v).to_nano().to_sec());
	};

	return 0;
}

fn Duration sum_durations(List{Duration}* ds)
{
	Duration sum;

	foreach (d : ds) {
		sum += d;
	}

	return sum;
}

fn void add_stat(Stats* stats, String title, Time since)
{
	if (!ENABLE_PROFILING) return;

	List{Duration}* ds = stats.get_or_create_ref(title);

	if (!ds.is_initialized()) {
		ds.init(mem);
	}

	ds.push(time::now() - since);
}
alias Cond = ConditionVariable;

alias Stats = HashMap{String, List{Duration}};

struct StatsNode {
	usz        id;
	Stats      stats;
	StatsNode* next;
}

struct Range {
	ulong start;
	ulong end;
}

alias Ranges = RingBuffer{Range[1024]};

struct Payload {
	struct result {
		ulong value;
		Mutex mutex;
	}
	struct queue {
		usz    ready_count;
		Ranges ranges;
		Mutex  mutex;
		Cond   cond;
	}
	struct stats {
		StatsNode* head;
		Mutex      mutex;
	}
}

macro @mutex_init(#parent_struct)
{
	if (catch err = #parent_struct.mutex.init()) {
		io::printfn($stringify(#parent_struct) +++ ".mutex.init: %s", err);
		os::exit(1);
	}
}

macro @mutex_destroy(#parent_struct)
{
	if (catch err = #parent_struct.mutex.destroy()) {
		io::printfn($stringify(#parent_struct) +++ ".mutex.destroy: %s", err);
		os::exit(1);
	}
}

macro @cond_init(#parent_struct)
{
	if (catch err = #parent_struct.cond.init()) {
		io::printfn($stringify(#parent_struct) +++ ".cond.init: %s", err);
		os::exit(1);
	}
}

macro @cond_destroy(#parent_struct)
{
	if (catch err = #parent_struct.cond.destroy()) {
		io::printfn($stringify(#parent_struct) +++ ".cond.destroy: %s", err);
		os::exit(1);
	}
}

macro @in_lock(#parent_struct; @body)
{
	@lock(#parent_struct);
	defer @unlock(#parent_struct);
	@body();
}

macro @lock(#parent_struct)
{
	if (catch err = #parent_struct.mutex.lock()) {
		io::printfn($stringify(#parent_struct) +++ ".mutex.lock: %s", err);
		os::exit(1);
	}
}

macro @unlock(#parent_struct)
{
	if (catch err = #parent_struct.mutex.unlock()) {
		io::printfn($stringify(#parent_struct) +++ ".mutex.unlock: %s", err);
		os::exit(1);
	}
}

macro @wait(#parent_struct)
{
	if (catch err = #parent_struct.cond.wait(&#parent_struct.mutex)) {
		io::printfn($stringify(#parent_struct) +++ ".cond.wait: %s", err);
		os::exit(1);
	}
}

macro @broadcast(#parent_struct)
{
	if (catch err = #parent_struct.cond.broadcast()) {
		io::printfn($stringify(#parent_struct) +++ ".cond.broadcast: %s", err);
		os::exit(1);
	}
}

macro @signal(#parent_struct)
{
	if (catch err = #parent_struct.cond.signal()) {
		io::printfn($stringify(#parent_struct) +++ ".cond.signal: %s", err);
		os::exit(1);
	}
}
