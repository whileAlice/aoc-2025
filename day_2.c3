import std::io;
import std::io::file;
import std::core::string;
import std::thread;
import std::collections::map;
import std::collections::list;
import libc;
import std::time;

const INPUT_PATH = "day_2_input.txt";
const THREAD_NUM = 1;

alias Cond = ConditionVariable;

struct QueueNode {
	ulong      value;
	QueueNode* next;
}

alias Stats = HashMap{String, List{Duration}};

struct StatsNode {
	usz        id;
	Stats      stats;
	StatsNode* next;
}

struct Payload {
	struct result {
		ulong value;
		Mutex mutex;
	}
	struct queue {
		usz        ready_count;
		QueueNode* head;
		Mutex      mutex;
		Cond       cond;
	}
	struct stats {
		StatsNode* head;
		Mutex      mutex;
	}
	bool should_quit;
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
	sn.stats.init(mem);

	add_stat(&sn.stats, "stats_init", thread_start);

	bool is_startup = true;

	while OUTER: (true) {
		QueueNode* n;

		Time queue_mutex_lock = time::now();

		if (catch err = p.queue.mutex.lock()) {
			io::printfn("thread queue mutex lock: %s", err);
		}

		add_stat(&sn.stats, "thread_queue_lock", queue_mutex_lock);

		Time wait_start = time::now();

		if (is_startup) {
			Time thread_startup = time::now();

			sn.id = p.queue.ready_count;
			p.queue.ready_count += 1;
			io::printfn("[worker %d] new ready count = %d, signaled queue cond!", sn.id, p.queue.ready_count);

			if (catch err = p.queue.cond.broadcast()) {
				io::printfn("thread queue cond broadcast: %s", err);
			}

			is_startup = false;

			add_stat(&sn.stats, "thread_startup", thread_startup);
		}

		if (!p.should_quit) {
			Time before_should_quit = time::now();

			if (is_startup) {
				io::printfn("[worker %d] queue cond broadcasting", sn.id);
				if (catch err = p.queue.cond.broadcast()) {
					io::printfn("thread queue cond broadcast: %s", err);
				}
			}

			Time cond_wait_start = time::now();

			if (catch err = p.queue.cond.wait(&p.queue.mutex)) {
				io::printfn("thread queue cond wait: %s", err);
			}

			add_stat(&sn.stats, "thread_queue_cond_wait", cond_wait_start);

			add_stat(&sn.stats, "thread_queue_wait_before_should_quit", before_should_quit);
		}

		if (p.queue.head == null && p.should_quit) {
			if (catch err = p.queue.mutex.unlock()) {
				io::printfn("thread queue mutex lock: %s", err);
			}

			io::printfn("[worker %d] p.queue.head is %d", sn.id, p.queue.head);
			add_stat(&sn.stats, "total_thread_wait_time_for_job", queue_mutex_lock);

			break;
		}

		if (p.should_quit) {
			add_stat(&sn.stats, "thread_wait_post_broadcast", wait_start);
		}

		if (p.queue.head == null || p.queue.ready_count < THREAD_NUM + 1) {
			if (catch err = p.queue.mutex.unlock()) {
				io::printfn("thread queue mutex lock: %s", err);
			}

			add_stat(&sn.stats, "thread_release_no_job", queue_mutex_lock);
			add_stat(&sn.stats, "total_thread_wait_time_for_job", queue_mutex_lock);
			continue;
		};

		n = p.queue.head;
		p.queue.head = p.queue.head.next;

		if (catch err = p.queue.mutex.unlock()) {
			io::printfn("thread queue mutex unlock: %s", err);
		}

		add_stat(&sn.stats, "total_thread_wait_time_for_job", queue_mutex_lock);

		Time begin_job = time::now();

		char[1024] buf;
		String num_str = string::bformat(&buf, "%d", n.value);

		add_stat(&sn.stats, "string_from_number", begin_job);

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
				// io::printfn("[worker %d] found value %d %s", sn.id, n.value, num_str);
				if (catch err = p.result.mutex.lock()) {
					io::printfn("thread result mutex lock: %s", err);
				}

				p.result.value += n.value;

				if (catch err = p.result.mutex.unlock()) {
					io::printfn("thread result mutex unlock: %s", err);
				}

				add_stat(&sn.stats, "processing_time (found)", begin_job);

				continue OUTER;
			}
		}

		add_stat(&sn.stats, "processing_time (not found)", begin_job);
	}

	Time last_lock_start = time::now();

	if (catch err = p.stats.mutex.lock()) {
		io::printfn("thread stats mutex lock: %s", err);
	}

	add_stat(&sn.stats, "total_thread_time", thread_start);
	add_stat(&sn.stats, "last_lock", last_lock_start);

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

	Time queue_create_start = time::now();

	foreach (range : ranges) {
		String[] pair = range.tsplit("-");
		ulong start = pair[0].to_ulong()!!;
		ulong end   = pair[1].to_ulong()!!;

		for (ulong x = start; x <= end; ++x) {
			if (catch err = p.queue.mutex.lock()) {
				io::printfn("main lock: %s", err);
			}

				QueueNode* new_head = tmalloc(QueueNode.sizeof);
				new_head.value = x;
				new_head.next = p.queue.head;
				p.queue.head = new_head;

			if (catch err = p.queue.mutex.unlock()) {
				io::printfn("main unlock: %s", err);
			}
		}
	}

	add_stat(&ps, "queue_create", queue_create_start);

	Time queue_broadcast_start = time::now();

	if (catch err = p.queue.mutex.lock()) {
		io::printfn("main lock 2: %s", err);
	}

		p.should_quit = true;

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
