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

fn int second_task_thread(void* arg)
{
	Time thread_start = time::now();

	Payload* p = arg;

	StatsNode* sn = malloc(StatsNode.sizeof);
	sn.stats.init(mem);

	add_stat(&sn.stats, "stats init", thread_start);

	@in_lock(p.queue)
	{
		sn.id = p.queue.ready_count;
		p.queue.ready_count += 1;
		io::printfn("[worker %d] ready count set to %d, broadcasting queue cond",
					sn.id, p.queue.ready_count);

		@broadcast(p.queue);

		add_stat(&sn.stats, "thread startup", thread_start);

		while (p.queue.ready_count < THREAD_COUNT + 1) {
			io::printfn("[worker %d] waiting...", sn.id);

			@wait(p.queue);

			io::printfn("[worker %d] woken up", sn.id);
		}

		add_stat(&sn.stats, "thread wait", thread_start);
	};

	while (true) {
		Range? range;

		@in_lock(p.queue)
		{
			if (p.queue.ranges.written == 0) break;
			range = p.queue.ranges.pop();
		};

		if (catch err = range) {
			io::printfn("thread queue ranges pop: %s", err);
			os::exit(1);
		}

		// TODO: I think this could be optimized by noticing that subsequent numbers
		// don't differ much from previous ones, that only a difference of x digits
		// could possibly change the result compared to the previous number.
		char[1024] buf;
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

				add_stat(&sn.stats, "processing_time (found)", processing_start);

				continue RANGE;
			}

		add_stat(&sn.stats, "processing_time (not found)", processing_start);
		}
	}

	add_stat(&sn.stats, "total_thread_time", thread_start);

	@in_lock(p.stats)
	{
		sn.next = p.stats.head;
		p.stats.head = sn;
	};

	io::printfn("[worker %d] thread returning", sn.id);

	return 0;
}

fn int main()
{
	Stats ps;
	ps.init(mem);

	Time main_start = time::now();

	String? input = ((String)file::load_temp(INPUT_PATH)).trim_right();
	if (catch err = input) {
		io::printfn("failed to open %s: %s", INPUT_PATH, err);

		os::exit(1);
	}

	add_stat(&ps, "process_file", main_start);

	Time task_1_start = time::now();

	ulong result = 0;

	String[] ranges = input.tsplit(",");
	if (0) {
	foreach (range : ranges) {
		String[] pair = range.tsplit("-");
		ulong start = pair[0].to_ulong()!!;
		ulong end   = pair[1].to_ulong()!!;

		for (ulong x = start; x <= end; ++x) {
			String num_str = string::tformat("%d", x);
			libc::DivResult div_result = libc::div(num_str.len, 2);

			bool is_odd   = div_result.rem != 0;
			uint midpoint = div_result.quot;

			if (is_odd) continue;

			String part1 = num_str[..midpoint - 1];
			String part2 = num_str[midpoint..];

			if ((part1.to_uint()!!) == (part2.to_uint()!!)) {
				result += x;
			}
		}
	}
	}

	io::printfn("result [1]: %d", result);

	add_stat(&ps, "task_1", task_1_start);

	Time payload_init_start = time::now();

	Payload* p = tmalloc(Payload.sizeof);
	@cond_init(p.queue);
	defer @cond_destroy(p.queue);
	@mutex_init(p.queue);
	defer @mutex_destroy(p.queue);
	@mutex_init(p.result);
	defer @mutex_destroy(p.result);
	@mutex_init(p.stats);
	defer @mutex_destroy(p.stats);

	add_stat(&ps, "payload_init", payload_init_start);

	Time thread_create_start = time::now();

	Thread[THREAD_COUNT] threads;
	foreach (i, &thread : threads) {
		if (catch err = thread.create(&second_task_thread, p)) {
			io::printfn("thread %d create: %s", i, err);
		}
	}

	add_stat(&ps, "create_threads", thread_create_start);

	Time queue_create_start = time::now();

	@in_lock(p.queue)
	{
		foreach (range : ranges) {
			String[] pair = range.tsplit("-");
			ulong start = pair[0].to_ulong()!!;
			ulong end   = pair[1].to_ulong()!!;

			p.queue.ranges.push({ start = start, end = end });
		}

		io::printfn("[producer] queue is ready");
		add_stat(&ps, "queue_create", queue_create_start);

		p.queue.ready_count += 1;
		io::printfn("[producer] ready count set to %d", p.queue.ready_count);

		@broadcast(p.queue);
		io::printfn("[producer] waking up threads");

		Time wait_for_threads_start = time::now();

		while (p.queue.ready_count < THREAD_COUNT + 1) {
			io::printfn("[producer] waiting for threads...");

			@wait(p.queue);

			io::printfn("[producer] woken up!");
		}

		add_stat(&ps, "waiting_for_threads", wait_for_threads_start);
	};

	io::printfn("[producer] TIME TO DO WORK");

	Time thread_join_start = time::now();

	foreach (i, &thread : threads) {
		io::printfn("joining thread %d", i);
		if (catch err = thread.join()) {
			io::printfn("thread %d join: %s", i, err);
		}
	}

	add_stat(&ps, "thread_join", thread_join_start);

	io::printfn("result [2]: %d", p.result.value);

	add_stat(&ps, "total_main_time", main_start);

	if (!ENABLE_PROFILING) return 0;

	io::printfn("==============================================================");
	Duration total_processing_time;
	Duration max_processing_time;
	Duration string_from_number_time;

	while (p.stats.head != null) {
		p.stats.head.stats.@each(;String k, List{Duration} v) {
			if (k.contains("processing")) {
				total_processing_time += sum_durations(&v);
				if (max_processing_time < sum_durations(&v)) {
					max_processing_time = sum_durations(&v);
				}
			}

			if (k.contains("string")) {
				string_from_number_time += sum_durations(&v);
			}

			io::printfn("[%d] %s: %s s", p.stats.head.id, k, sum_durations(&v).to_nano().to_sec());
		};

		p.stats.head = p.stats.head.next;
	}
	io::printfn("==============================================================");
	io::printfn("total processing time: %s s", total_processing_time.to_nano().to_sec());
	io::printfn("max processing time: %s s", max_processing_time.to_nano().to_sec());
	io::printfn("avg processing time: %s s", total_processing_time.to_nano().to_sec() / THREAD_COUNT);
	io::printfn("avg string from number time: %s s", string_from_number_time.to_nano().to_sec() / THREAD_COUNT);
	io::printfn("==============================================================");

	ps.@each(;String k, List{Duration} v) {
		if (k.contains("processing")) {
			total_processing_time += sum_durations(&v);
		}

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
