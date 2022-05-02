// Usage: lepa FILE
// This is a simple program that reads from FILE lines starting with a letter
// pair, that is a word consisting of two capital letters such as XY, saves
// them in a table and lets the user access and visualize them in different
// ways. It is intended to be a tool to train a memory scheme for letter pair
// (e.g. for memory sports), but I mostly wrote it to try out Hare.

use ascii;
use bufio;
use encoding::utf8;
use fmt;
use fs;
use io;
use math::random;
use os;
use strings;
use time;

type notlp = !void;

def N: u32 = 26;
let table: [N][N]str = [[""...]...];
const commands: [_](str, *fn() void, str) = [
	("r", &dorand, "Start random training session"),
	("?", &printhelp, "Print help"),
	("q", &quit, "Quit"),
];

// Start random training session
fn dorand() void = {
	let pairs: [N*N](u32, u32) = [(0, 0)...];
	let k = makeallpairs(pairs[0..N*N]);
	let ran = math::random::init(time::unix(time::now(0)): u64);
	for (true) {
		const p = pairs[math::random::u32n(&ran, k)];
		fmt::printfln("{}", pairstr(p))!;
		if (waitline()) return;
		fmt::printfln("{}", table[p.0][p.1])!;
		if (waitline()) return;
	};
};

// Print help
fn printhelp() void = {
	fmt::printfln("Available commands:")!;
	for (let i: size = 0; i < len(commands); i += 1)
		fmt::printfln("{}\t{}", commands[i].0, commands[i].2)!;
};

// Quit
fn quit() void = os::exit(0);

fn mainloop() void = {
	for (true) {
		let line: str = match(bufio::scanline(os::stdin)) {
		case io::error =>
			fmt::fatal("Error during io");
		case io::EOF =>
			fmt::printfln("^D")!;
			os::exit(0);
		case let line: []u8 =>
			yield strings::fromutf8(line);
		};
		let i: size = 0;
		for (i < len(commands); i += 1) {
			if (line == commands[i].0) {
				commands[i].1();
				break;
			};
		};
		if (i == len(commands))
			fmt::printfln("?")!;
		free(line);
	};
};

// Determines if c is one of the N characters declared as letters
fn isvalidle(c: rune) bool = ascii::isupper(c);

// Index corresponding to character c in the table
fn index(c: rune) u32 = (c: u32) - ('A': u32);

// Character corresponding to index i in the table
fn rundex(i: u32) rune = (i + ('A': u32)): rune;

// Rune to string
// TODO is there really no standard library function for this?
fn runetostring(r: rune) str = {
	let arr: []u8 = encoding::utf8::encoderune(r);
	return strings::fromutf8(arr);
};

// Pair of indexes to string
fn pairstr(p: (u32, u32)) str = {
	const s1 = strings::dup(runetostring(rundex(p.0: u32)));
	const s2 = strings::dup(runetostring(rundex(p.1: u32)));
	return strings::concat(s1, s2);
};

// Read the table of letter pairs from file
fn read(file: (io::file | fs::error)) void = {
	const f = match(file) {
	case let f: io::file =>
		yield f;
	case let e: fs::error =>
		fmt::fatal("Error reading file: {}", fs::strerror(e));
	};
	const lines = match(io::drain(f)) {
	case let lines: []u8 =>
		yield strings::fromutf8(lines);
	case io::error =>
		fmt::fatal("Error reading table");
	};
	const lines = strings::split(lines, "\n");

	for (let i = 0z; i < len(lines); i += 1) {
		const runes: []rune = strings::runes(lines[i]);
		if (len(lines[i]) == 0 || runes[0] == '#')
			continue;
		const c1 = runes[0];
		const c2 = runes[1];
		if (!(isvalidle(c1) && isvalidle(c2)))
			fmt::fatal("Error reading line: {}", lines[i]);
		let j: size = 2;
		for (j < len(runes) && ascii::isspace(runes[j]))
			j += 1;
		const word: str = strings::sub(lines[i], j, strings::end);
		if (len(word) > 0)
			table[index(c1)][index(c2)] = strings::dup(word);
		free(runes);
	};
	free(lines);
};

// Make list of all non-empty pairs
fn makeallpairs(allpairs: [](u32, u32)) u32 = {
	let k: u32 = 0;
	for (let i: u32 = 0; i < N; i += 1) {
		for (let j: u32 = 0; j < N; j += 1) {
			if (table[i][j] != "") {
				allpairs[k] = (i, j);
				k += 1;
			};
		};
	};
	return k;
};

// Print one entry of the tabl
fn printentry(p: (str | (u32, u32))) (void | notlp) = {
	const ind: (u32, u32) = match(p) {
	case let pair: (u32, u32) =>
		yield pair;
	case let s: str =>
		yield if (len(s) != 2) {
			return notlp;
		} else {
			const runes = strings::runes(s);
			yield (index(runes[0]), index(runes[1]));
		};
	};
	const i = ind.0;
	const j = ind.1;
	if (table[i][j] != "") {
		const r1: rune = rundex(i: u32);
		const r2: rune = rundex(j: u32);
		fmt::printfln("{}{}:\t{}", r1, r2, table[i][j])!;
	};
};

// Print one line of the table
fn printline(c: (u32 | rune)) void = {
	const i: u32 = match(c) {
	case let i: u32 =>
		yield i;
	case let r: rune =>
		yield index(r);
	};
	fmt::printfln("{}:", rundex(i))!;
	for (let j: size = 0; j < len(table[i]); j += 1) {
		// TODO: not ignore error?
		printentry((i: u32, j: u32))!;
	};
};

// Print all non-empty letter pairs
fn printall() void = {
	fmt::println("List of pairs:")!;
	for (let i: size = 0; i < len(table); i += 1) {
		printline(i: u32);
		fmt::println("")!;
	};
};

// Read a line from standard input, return true if EOF
fn waitline() bool = {
	match(bufio::scanline(os::stdin)) {
	case io::error =>
		fmt::fatal("Error during io");
	case []u8 =>
		return false;
	case io::EOF =>
		fmt::printfln("^D")!;
		return true;
	};
};

export fn main() void = {
	if (len(os::args) != 2)
		fmt::fatal("Usage: {} file", os::args[0]);

	read(os::open(os::args[1]));

	mainloop();
};
