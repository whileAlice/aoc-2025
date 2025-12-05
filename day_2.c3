import std::io;
import std::io::file;
import std::core::string;
import std::thread;
import libc;

// FIXME: threads seem to be broken on musl ;_;
// let's check c3 0.77, maybe it's better there.
// otherwise, let's file a bug.

const INPUT_PATH = "day_2_input.txt";
const THREAD_NUM = 16;

alias Cond = ConditionVariable;

struct QueueNode {
	ulong      value;
	QueueNode* next;
}

struct Payload {
	struct result {
		ulong value;
		Mutex mutex;
	}
	struct queue {
		QueueNode* head;
		Mutex      mutex;
		Cond       cond;
	}
}


fn int thread_fn(void* arg)
{
	Payload* p = arg;

	if (p.queue.head == null) return 0;

	QueueNode* n;

	p.queue.mutex.lock()!!;

	n = p.queue.head;
	p.queue.head = p.queue.head.next;

	p.queue.mutex.unlock()!!;

	String num_str = string::format(mem, "%d", 2);
	defer free(num_str);

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
			p.result.mutex.lock()!!;

			p.result.value += n.value;

			p.result.mutex.unlock()!!;

			return 0;
		}
	}

	return 0;
}

fn int main()
{
	String? input = ((String)file::load_temp(INPUT_PATH)).trim_right();
	if (catch err = input) {
		io::printfn("failed to open %s: %s", INPUT_PATH, err);

		return 1;
	}

	ulong result = 0;

	// numbers repeated twice
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

	Payload* p = malloc(Payload.sizeof);
	p.queue.head = malloc(QueueNode.sizeof);
	p.queue.cond.init()!!;
	defer p.queue.cond.destroy()!!;
	p.queue.mutex.init()!!;
	defer p.queue.mutex.destroy()!!;
	p.result.mutex.init()!!;
	defer p.result.mutex.destroy()!!;

	Thread[THREAD_NUM]* threads = malloc(Thread.sizeof * THREAD_NUM);
	foreach (i, &thread : threads) {
		thread.create(&thread_fn, p)!!;
	}

	// numbers repeated n times
	result = 0;
	foreach (range : ranges) {
		String[] pair = range.tsplit("-");
		ulong start = pair[0].to_ulong()!!;
		ulong end   = pair[1].to_ulong()!!;

		for (ulong x = start; x <= end; ++x) {
			p.queue.mutex.lock()!!;
				p.queue.head.value = x;
				QueueNode* new_head = tmalloc(QueueNode.sizeof);
				new_head.next = p.queue.head;
				p.queue.head = new_head;
			p.queue.mutex.unlock()!!;
		}
	}

	io::printfn("result [2]: %d", result);

	return 0;
}
