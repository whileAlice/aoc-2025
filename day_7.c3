import std::io;
import std::io::file;
import std::collections::list;
import std::collections::set;
import std::collections::map;

const INPUT_PATH = "day_7_input.txt";

alias Diagram = List{List{bool}};
alias XSet    = HashSet{usz};
alias XMap    = HashMap{usz, ulong};

fn int main()
{
	String? raw_input = ((String)file::load_temp(INPUT_PATH));
	if (catch err = raw_input) {
		io::printfn("failed to open %s: %s", INPUT_PATH, err);

		return 1;
	}

	String[] raw_lines = raw_input.trim_right().tsplit("\n");

	Diagram diagram;
	diagram.tinit();

	usz first_beam_origin_x;
	foreach (y, &raw_line : raw_lines) {
		List{bool} row;
		row.tinit();

		foreach (x, ch : raw_line) {
			switch (ch) {
				case '^':
					row.push(true);
				case '.':
					row.push(false);
				case 'S':
					first_beam_origin_x = x;
					row.push(false);
				default:
					unreachable();
			}
		}

		diagram.push(row);
	}

	XSet beam_origin_xs;
	beam_origin_xs.add(first_beam_origin_x);

	List{usz} new_origin_xs;
	new_origin_xs.tinit();

	uint split_count = 0;
	foreach (y, &row : diagram) {
		usz i = 0;
		while (i < beam_origin_xs.len()) {
			defer ++i;

			usz origin_x = beam_origin_xs.tvalues()[i];

			// we've hit a splitter
			if (diagram[y][origin_x]) {
				split_count += 1;

				// assuming always safe since this input is safe
				new_origin_xs.push(origin_x - 1);
				new_origin_xs.push(origin_x + 1);

				beam_origin_xs.remove(origin_x);
				i -= 1;
			}
		}

		// adding after the loop to not interfere with it
		beam_origin_xs.add_all(new_origin_xs.array_view());
		new_origin_xs.clear();
	}

	io::printfn("[task 1] split count: %d", split_count);

	XMap beam_origin_timelines;
	beam_origin_timelines.tinit();
	beam_origin_timelines.set(first_beam_origin_x, 1);

	XMap new_origin_timelines;
	new_origin_timelines.tinit();

	foreach (y, &row : diagram) {
		usz i = 0;
		while (i < beam_origin_timelines.len()) {
			defer ++i;

			usz origin_x = beam_origin_timelines.tkeys()[i];

			if (diagram[y][origin_x]) {
				ulong* left  = new_origin_timelines.get_or_create_ref(origin_x - 1);
				      *left += beam_origin_timelines[origin_x]!!;

				ulong* right  = new_origin_timelines.get_or_create_ref(origin_x + 1);
				      *right += beam_origin_timelines[origin_x]!!;

				beam_origin_timelines.remove(origin_x);
				i -= 1;
			}
		}

		foreach (key : new_origin_timelines.tkeys()) {
			ulong* val  = beam_origin_timelines.get_or_create_ref(key);
				  *val += new_origin_timelines[key]!!;
		}
		new_origin_timelines.clear();
	}

	ulong timeline_count = 0;
	foreach (value : beam_origin_timelines.tvalues()) {
		timeline_count += value;
	}

	io::printfn("[task 2] timeline count: %d", timeline_count);

	return 0;
}
