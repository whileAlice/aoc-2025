import std::io;
import std::io::file;
import std::core::string;
import std::thread;
import std::collections::map;
import std::collections::list;
import std::collections::ringbuffer;
import libc;
import std::time;

const INPUT_PATH = "day_2_input.txt";
const THREAD_NUM = 4;

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
		usz        ready_count;
		bool       should_quit;
		Ranges     ranges;
		Mutex      mutex;
		Cond       cond;
	}
	struct stats {
		StatsNode* head;
		Mutex      mutex;
	}
}

fn void add_stat(Stats* stats, String title, Time since)
{
	List{Duration}* ds = stats.get_or_create_ref(title);

	if (!ds.is_initialized()) {
		ds.init(mem);
	}

	ds.push(time::now() - since);
}

fn int thread_fn(void* arg)
{
	Time thread_start = time::now();

	Payload* p = arg;

	StatsNode* sn = malloc(StatsNode.sizeof);
	sn.stats.init(mem, 1024 * 1024);

	add_stat(&sn.stats, "stats init", thread_start);

	bool is_startup = true;
	while (true) {
		if (catch err = p.queue.mutex.lock()) {
			io::printfn("thread queue mutex lock: %s", err);
		}
		defer {
			if (catch err = p.queue.mutex.unlock()) {
				io::printfn("thread queue mutex unlock: %s", err);
			}
		}

		if (is_startup) {
			sn.id = p.queue.ready_count;
			p.queue.ready_count += 1;
			io::printfn("[worker %d] ready count set to %d, broadcasting queue cond", sn.id, p.queue.ready_count);

			if (catch err = p.queue.cond.broadcast()) {
				io::printfn("thread queue cond broadcast: %s", err);
			}

			is_startup = false;

			add_stat(&sn.stats, "thread startup", thread_start);
		}

		if (catch err = p.queue.cond.wait(&p.queue.mutex)) {
			io::printfn("thread queue cond wait: %s", err);
		}

		add_stat(&sn.stats, "thread wait", thread_start);

		if (p.queue.ready_count < THREAD_NUM + 1) {
			add_stat(&sn.stats, "thread woken - other threads not ready", thread_start);

			continue;
		} else {
			break;
		}
	}

	while (p.queue.ranges.written > 0) {
		if (catch err = p.queue.mutex.lock()) {
			io::printfn("thread queue mutex lock: %s", err);
		}

		Range? range = p.queue.ranges.pop();
		if (catch err = range) {
			io::printfn("queue ranges pop: %s", err);
			return 1;
		}
		io::printfn("%d %d", range.start, range.end);

		if (catch err = p.queue.mutex.unlock()) {
			io::printfn("thread queue mutex unlock: %s", err);
		}

		ulong x = range.start;
		while RANGE: (x <= range.end) {
			defer ++x;
			Time begin_job = time::now();

			char[1024] buf;
			String num_str = string::bformat(&buf, "%d", x);

			// add_stat(&sn.stats, "string_from_number", begin_job);

			for (uint div = 2; div <= num_str.len; ++div) {
				if (num_str.len % div != 0) continue;

				bool found = true;
				uint current_pos = 0;
				uint sub_num_len = num_str.len / div;
				while COMPARE: (current_pos < sub_num_len) {
					uint current_repetition = 1;
					while (current_repetition < div) {
						if (num_str[current_pos] !=
						    num_str[current_repetition * sub_num_len + current_pos]) {
							found = false;

							break COMPARE;
						}

						current_repetition += 1;
					}

					current_pos += 1;
				}

				if (found) {
					// io::printfn("[worker %d] found value %d %s", sn.id, x, num_str);
					if (catch err = p.result.mutex.lock()) {
						io::printfn("thread result mutex lock: %s", err);
					}

					p.result.value += x;

					if (catch err = p.result.mutex.unlock()) {
						io::printfn("thread result mutex unlock: %s", err);
					}

					add_stat(&sn.stats, "processing_time (found)", begin_job);

					continue RANGE;
				}
			}

		add_stat(&sn.stats, "processing_time (not found)", begin_job);
		}
	}

	if (catch err = p.stats.mutex.lock()) {
		io::printfn("thread stats mutex lock: %s", err);
	}

	add_stat(&sn.stats, "total_thread_time", thread_start);

	sn.next = p.stats.head;
	p.stats.head = sn;

	if (catch err = p.stats.mutex.unlock()) {
		io::printfn("thread stats mutex unlock: %s", err);
	}

	io::printfn("[worker %d] returning", sn.id);
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

		return 1;
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
	if (catch err = p.queue.cond.init()) {
		io::printfn("queue cond init: %s", err);
	}
	defer {
		if (catch err = p.queue.cond.destroy()) {
			io::printfn("queue cond destroy: %s", err);
		}
	}
	if (catch err = p.queue.mutex.init()) {
		io::printfn("queue mutex init: %s", err);
	}
	defer {
		if (catch err = p.queue.mutex.destroy()) {
			io::printfn("queue mutex destroy: %s", err);
		}
	}
	if (catch err = p.result.mutex.init()) {
		io::printfn("result mutex init: %s", err);
	}
	defer {
		if (catch err = p.result.mutex.destroy()) {
			io::printfn("result mutex destroy: %s", err);
		}
	}
	if (catch err = p.stats.mutex.init()) {
		io::printfn("stats mutex init: %s", err);
	}
	defer {
		if (catch err = p.stats.mutex.destroy()) {
			io::printfn("stats mutex destroy: %s", err);
		}
	}

	add_stat(&ps, "payload_init", payload_init_start);

	Time thread_create_start = time::now();

	Thread[THREAD_NUM] threads;
	foreach (i, &thread : threads) {
		if (catch err = thread.create(&thread_fn, p)) {
			io::printfn("thread %d create: %s", i, err);
		}
	}

	add_stat(&ps, "create_threads", thread_create_start);

	Time queue_create_start = time::now();

	if (catch err = p.queue.mutex.lock()) {
		io::printfn("main lock: %s", err);
	}

	foreach (range : ranges) {
		String[] pair = range.tsplit("-");
		ulong start = pair[0].to_ulong()!!;
		ulong end   = pair[1].to_ulong()!!;

		p.queue.ranges.push({ start = start, end = end });
	}

	if (catch err = p.queue.mutex.unlock()) {
		io::printfn("main unlock: %s", err);
	}

	add_stat(&ps, "queue_create", queue_create_start);

	bool is_startup = true;

	Time wait_for_threads_start = time::now();

	while (true) {
		if (catch err = p.queue.mutex.lock()) {
			io::printfn("main queue mutex lock: %s", err);
		}
		defer {
			if (catch err = p.queue.mutex.unlock()) {
				io::printfn("main queue mutex unlock: %s", err);
			}
		}

		if (is_startup) {
			p.queue.ready_count += 1;

			is_startup = false;
		}

		io::printfn("[producer] ready count = %d", p.queue.ready_count);

		if (p.queue.ready_count < THREAD_NUM + 1) {
			io::printfn("[producer] waking up threads");
			// TODO: maybe rename this cond to account for this?
			if (catch err = p.queue.cond.broadcast()) {
				io::printfn("main queue cond broadcast: %s", err);
			}

			io::printfn("[producer] waiting for threads...");
			if (catch err = p.queue.cond.wait(&p.queue.mutex)) {
				io::printfn("main queue cond wait: %s", err);
			}

			io::printfn("[producer] woken up!");
		} else {
			break;
		}
	}

	add_stat(&ps, "waiting_for_threads", wait_for_threads_start);

	io::printfn("[producer] TIME TO DO WORK");

	Time queue_broadcast_start = time::now();

	if (catch err = p.queue.mutex.lock()) {
		io::printfn("main lock 2: %s", err);
	}

		p.queue.should_quit = true;

		io::printfn("processing batch ready!");
		if (catch err = p.queue.cond.broadcast()) {
			io::printfn("main cond broadcast 2: %s", err);
		}

	if (catch err = p.queue.mutex.unlock()) {
		io::printfn("main unlock 2: %s", err);
	}

	add_stat(&ps, "queue_broadcast", queue_broadcast_start);

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
	io::printfn("avg processing time: %s s", total_processing_time.to_nano().to_sec() / THREAD_NUM);
	io::printfn("avg string from number time: %s s", string_from_number_time.to_nano().to_sec() / THREAD_NUM);
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
