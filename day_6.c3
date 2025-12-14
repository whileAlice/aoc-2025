import std::io;
import std::io::file;
import std::collections::list;

const INPUT_PATH = "day_6_input.txt";

alias Homework = List{List{ulong}};

fn int main()
{
	String? raw_input = ((String)file::load_temp(INPUT_PATH));
	if (catch err = raw_input) {
		io::printfn("failed to open %s: %s", INPUT_PATH, err);

		return 1;
	}

	String[] raw_lines = raw_input.trim_right().tsplit("\n");
	Homework homework;
	homework.init(tmem);

	foreach (&raw_line : raw_lines[0..^2]) {
		Splitter sp = raw_line.tokenize(" ");

		usz i = 0;
		while (try s = sp.next()) {
			defer ++i;

			if (homework.len() < i + 1) {
				List{ulong} sequence;
				sequence.init(tmem);
				homework.push(sequence);
			}

			homework[i].push(s.to_ulong()!!);
		}
	}

	List{char} operators;
	operators.init(tmem);
	Splitter sp = raw_lines[^1].tokenize(" ");

	while (try s = sp.next()) {
		operators.push(s[0]);
	}

	ulong total = 0;
	foreach (i, &sequence : homework) {
		total += apply_operation(sequence, operators[i]);
	}

	io::printfn("[task 1] sum of all results: %d", total);

	List{DString} raw_rotated;
	raw_rotated.init(tmem);

	foreach (&raw_line : raw_lines[0..^2]) {
		foreach (i, ch : raw_line) {
			if (raw_rotated.len() < i + 1) {
				DString raw_number;
				raw_number.init(tmem);
				raw_rotated.push(raw_number);
			}

			raw_rotated[i].append(ch);
		}
	}

	Homework actual_homework;
	actual_homework.init(tmem);

	usz j = 0;
	foreach (&ds : raw_rotated) {
		if (actual_homework.len() < j + 1) {
			List{ulong} sequence;
			sequence.init(tmem);
			actual_homework.push(sequence);
		}

		String trimmed = ds.str_view().trim();

		if (trimmed == "") {
			++j;
			continue;
		}

		actual_homework[j].push(trimmed.to_ulong()!!);
	}

	ulong actual_total = 0;
	foreach (i, &sequence : actual_homework) {
		actual_total += apply_operation(sequence, operators[i]);
	}

	io::printfn("[task 2] actual sum of all results: %d", actual_total);

	return 0;
}

fn ulong apply_operation(List{ulong}* sequence, char operator)
{
	ulong total = operator == '*' ? 1 : 0;

	foreach (num : sequence) {
		total = operator == '*' ? total * num : total + num;
	}

	return total;
}
