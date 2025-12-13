import std::io;
import std::io::file;
import std::collections::list;
import std::math;

const INPUT_PATH = "day_5_input.txt";

fn int main()
{
	String? raw_input = ((String)file::load_temp(INPUT_PATH));
	if (catch err = raw_input) {
		io::printfn("failed to open %s: %s", INPUT_PATH, err);

		return 1;
	}

	String[] raw_lines = raw_input.trim_right().tsplit("\n");

	List{Range} ranges;
	ranges.init(mem);

	String* current_line = &raw_lines[0];
	while (*current_line != "") {
		String[] raw_range = current_line.tsplit("-");
		Range range = {
			.start = raw_range[0].to_ulong()!!,
			.end   = raw_range[1].to_ulong()!!,
		};

		ranges.push(range);
		current_line++;
	}

	List{ulong} items;
	items.init(mem);

	current_line++;
	uint fresh_count = 0;
	while (*current_line != "") {
		ulong item = current_line.to_ulong()!!;

		foreach (&range : ranges) {
			if (item >= range.start && item <= range.end) {
				fresh_count += 1;
				break;
			}
		}

		current_line++;
	}

	List{Range} solitary_ranges;
	solitary_ranges.init(mem);

	// pop a new range eater only if no new intersections have been found
	// for the previous one!
	bool  should_pop = true;
	Range range_eater;
	while (ranges.len() > 0) {
		if (should_pop) {
			range_eater = ranges.pop()!!;
		}

		should_pop = true;
		int i      = 0;
		while (i < ranges.len()) {
			defer ++i;

			Range* current_range = &ranges[i];

			if ((current_range.start < range_eater.start && current_range.end < range_eater.start) ||
				(current_range.start > range_eater.end && current_range.end > range_eater.end)) {
				continue;
			}

			// there's an intersection, don't pop until there are no more intersections
			should_pop = false;

			range_eater.start = math::min(current_range.start, range_eater.start);
			range_eater.end   = math::max(current_range.end,   range_eater.end);

			// range gobbled, remove it
			ranges.remove_at(i);
			i -= 1;
		}

		// no more intersections to gobble for this range
		if (should_pop) {
			solitary_ranges.push(range_eater);
		}
	}

	ulong total_fresh_count = 0;
	foreach (&range : solitary_ranges) {
		total_fresh_count += range.end - range.start + 1;
	}

	io::printfn("[task 1] fresh count %d", fresh_count);
	io::printfn("[task 2] total fresh count %d", total_fresh_count);

	return 0;
}

struct Range {
	ulong start;
	ulong end;
}
