# Recur for Gleam

[![Package Version](https://img.shields.io/hexpm/v/recur)](https://hex.pm/packages/recur)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/recur/)

A comprehensive library for parsing, generating, and working with iCalendar RRULE (recurrence rule) strings according to RFC 5545.

This library provides utilities to:
- Parse RRULE strings into structured data
- Generate RRULE strings from structured data  
- Calculate occurrence dates from recurrence rules
- Validate RRULE compliance with RFC 5545

## Installation

Add `recur` to your Gleam project:

```sh
gleam add recur
```

## Quick Start

```gleam
import recur
import gleam/time/timestamp
import gleam/io

pub fn main() {
  // Create a daily recurrence for 5 occurrences
  let rule = recur.new(recur.Daily) |> recur.with_count(5)
  
  // Convert to string
  let rrule_string = recur.to_string(rule)
  io.println(rrule_string)  // "FREQ=DAILY;COUNT=5"
  
  // Parse an RRULE string  
  let assert Ok(parsed) = recur.from_string("FREQ=WEEKLY;BYDAY=MO,WE,FR")
  
  // Generate occurrence dates
  let assert Ok(start) = timestamp.parse_rfc3339("2024-01-01T10:00:00Z")
  let occurrences = recur.generate_occurrences(rule, start, None)
  
  io.debug(occurrences)  // List of 5 timestamps
}
```

## Features

### Supported RRULE Parameters

This library supports the core RRULE parameters from RFC 5545:

- **FREQ**: The frequency of recurrence (Daily, Weekly, Monthly, Yearly, etc.)
- **COUNT**: Maximum number of occurrences  
- **UNTIL**: End date for the recurrence
- **INTERVAL**: Interval between occurrences
- **BYDAY**: Days of the week (with optional positional qualifiers)
- **BYMONTH**: Months of the year
- **WKST**: Week start day

*Note: `COUNT` and `UNTIL` are mutually exclusive per RFC 5545.*

### Date Calculation

The library integrates with `gleam_time` to provide real date calculation:

```gleam
import recur
import gleam/time/timestamp

// Find the next occurrence after a given date
let assert Ok(start) = timestamp.parse_rfc3339("2024-01-01T10:00:00Z")
let rule = recur.new(recur.Daily)

case recur.next_occurrence(rule, start) {
  Some(next) -> {
    // next is 2024-01-02T10:00:00Z
  }
  None -> {
    // No more occurrences (past UNTIL date, etc.)
  }
}
```

## Examples

### Daily Recurrence

```gleam
// Every day for 10 occurrences
let rule = recur.new(recur.Daily) |> recur.with_count(10)

// Every other day until Dec 31, 2024
let assert Ok(until) = timestamp.parse_rfc3339("2024-12-31T23:59:59Z")
let rule = recur.new(recur.Daily) 
  |> recur.with_interval(2)
  |> recur.with_until(until)
```

### Weekly Recurrence

```gleam
// Every Monday, Wednesday, and Friday
let weekdays = [
  recur.weekday_occurrence(recur.Monday),
  recur.weekday_occurrence(recur.Wednesday), 
  recur.weekday_occurrence(recur.Friday)
]
let rule = recur.new(recur.Weekly) |> recur.with_by_day(weekdays)

// Every 2 weeks on Tuesday and Thursday
let rule = recur.new(recur.Weekly)
  |> recur.with_interval(2)
  |> recur.with_by_day([
      recur.weekday_occurrence(recur.Tuesday),
      recur.weekday_occurrence(recur.Thursday)
    ])
```

### Monthly Recurrence  

```gleam
// First and third Monday of each month
let positioned_weekdays = [
  recur.weekday_occurrence_with_number(recur.Monday, 1),  // First Monday
  recur.weekday_occurrence_with_number(recur.Monday, 3)   // Third Monday
]
let rule = recur.new(recur.Monthly) |> recur.with_by_day(positioned_weekdays)

// Last Friday of each month
let last_friday = [recur.weekday_occurrence_with_number(recur.Friday, -1)]
let rule = recur.new(recur.Monthly) |> recur.with_by_day(last_friday)
```

### Yearly Recurrence

```gleam
// Every June and December
let rule = recur.new(recur.Yearly) |> recur.with_by_month([6, 12])
```

### Parsing Existing RRULEs

```gleam
// Parse complex RRULE strings
let complex = "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;COUNT=20"
let assert Ok(rule) = recur.from_string(complex)

// Convert back to string
let regenerated = recur.to_string(rule)
```

## API Reference

### Core Functions

- `new(frequency)` - Create a new RRULE with the specified frequency
- `to_string(rrule)` - Convert an RRULE to string format  
- `from_string(string)` - Parse an RRULE string
- `is_valid(rrule)` - Validate an RRULE according to RFC 5545

### Builder Functions

- `with_count(rrule, count)` - Set maximum occurrences (clears UNTIL)
- `with_until(rrule, timestamp)` - Set end date (clears COUNT)  
- `with_interval(rrule, interval)` - Set interval between occurrences
- `with_by_day(rrule, weekdays)` - Set days of the week
- `with_by_month(rrule, months)` - Set months of the year
- `with_week_start(rrule, weekday)` - Set week start day

### Date Calculation

- `next_occurrence(rrule, from)` - Find the next occurrence after a timestamp
- `generate_occurrences(rrule, start, limit)` - Generate a list of occurrences

### Utility Functions

- `weekday_occurrence(weekday)` - Create a simple weekday (e.g., "MO")
- `weekday_occurrence_with_number(weekday, n)` - Create positioned weekday (e.g., "1MO")
- `get_frequency(rrule)` - Get the frequency
- `get_interval(rrule)` - Get the interval (defaults to 1)
- `has_end_condition(rrule)` - Check if rule has COUNT or UNTIL

## RFC 5545 Compliance

This library implements the RRULE specification from [RFC 5545](https://tools.ietf.org/html/rfc5545) with the following compliance notes:

- ✅ All core frequency types supported (SECONDLY, MINUTELY, HOURLY, DAILY, WEEKLY, MONTHLY, YEARLY)
- ✅ COUNT and UNTIL parameters (mutually exclusive)
- ✅ INTERVAL parameter  
- ✅ BYDAY parameter with positional qualifiers
- ✅ BYMONTH parameter
- ✅ WKST parameter
- ⚠️ Some advanced BY* parameters are parsed but not used in date calculation
- ⚠️ BYDAY positional qualifiers currently simplified in date calculation

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam docs build  # Generate documentation
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.
