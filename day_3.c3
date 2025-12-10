import std::io;
import std::io::file;
import std::math;
import std::collections::pair;
import std::collections::list;

const INPUT_PATH         = "day_3_input.txt";
const INPUT_NUMBER_LEN   = 100;
// const INPUT_NUMBER_LEN   = 15; // test
const TASK_2_JOLTAGE_LEN = 12;

fn int main()
{
	String? raw_input = ((String)file::load_temp(INPUT_PATH));
	if (catch err = raw_input) {
		io::printfn("failed to open %s: %s", INPUT_PATH, err);

		return 1;
	}

	String[] raw_numbers = raw_input.trim_right().tsplit("\n");

	ulong total_joltage = 0;

	foreach (raw_number : raw_numbers) {
		uint max_joltage = 0;

		foreach (i, tens_raw : raw_number[..raw_number.len - 2]) {
			uint tens = parse_digit(tens_raw)!!;

			foreach (ones_raw : raw_number[i + 1..]) {
				uint ones = parse_digit(ones_raw)!!;
				uint joltage = tens * 10 + ones;

				if (joltage > max_joltage) {
					max_joltage = joltage;
				}
			}
		}

		total_joltage += max_joltage;
	}

	io::printfn("[task 1] total joltage: %d", total_joltage);

	total_joltage = 0;

	uint[INPUT_NUMBER_LEN] digits;
	foreach (raw_number : raw_numbers) {
		ulong max_joltage = 0;

					digits             = raw_number_to_digit_array(raw_number);
		List{uint*} max_digit_pointers =
			get_max_digit_pointers(&digits, TASK_2_JOLTAGE_LEN);

		uptr offset = 0;
		while (max_digit_pointers.len() > 1 && offset < TASK_2_JOLTAGE_LEN) {
			offset += 1;

			uint max = 0;
			foreach (digit_ptr : max_digit_pointers) {
				if (*digit_ptr > max) {
					max = *digit_ptr;
				}
			}

			// FIXME: they don't have to be consecutive!
			foreach (i, digit_ptr : max_digit_pointers) {
				if (*digit_ptr < max) {
					max_digit_pointers.remove_at(i);
				}
			}
		}

		for (uint i = 0; i < TASK_2_JOLTAGE_LEN; ++i) {
			max_joltage += (ulong)math::pow(10, TASK_2_JOLTAGE_LEN - i - 1) *
						   *(max_digit_pointers[0] + i);
		}

		total_joltage += max_joltage;
		io::printfn("max_joltage: %d", max_joltage);
	}

	io::printfn("[task 2] total joltage: %d", total_joltage);

	return 0;
}

faultdef NOT_A_DIGIT;

fn uint? parse_digit(char ch)
{
	if (ch >= '0' && ch <= '9') {
		return ch - '0';
	} else {
		return NOT_A_DIGIT?;
	}
}

fn List{uint*} get_max_digit_pointers(uint[] digits, usz joltage_len)
{
	List{uint*} ptrs;
	ptrs.init(mem, INPUT_NUMBER_LEN);

	uint[] allowed_digits = digits[..digits.len - joltage_len];

	int max_digit = 0;
	foreach (digit : allowed_digits) {
		if (digit > max_digit) {
			max_digit = digit;
		}
	}

	foreach (i, digit : allowed_digits) {
		if (digit == max_digit) {
			ptrs.push(&digits[i]);
		}
	}

	return ptrs;
}

fn uint[INPUT_NUMBER_LEN] raw_number_to_digit_array(String raw_number)
{
	uint[INPUT_NUMBER_LEN] digits;

	foreach (i, raw_digit : raw_number) {
		digits[i] = parse_digit(raw_digit)!!;
	}

	return digits;
}
