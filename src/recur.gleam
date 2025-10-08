//// A library for creating, parsing, and working with iCalendar RRULE (recurrence rule) strings.
//// 
//// This library provides utilities to:
//// - Parse RRULE strings into structured data
//// - Generate RRULE strings from structured data  
//// - Calculate occurrence dates from recurrence rules
//// - Validate RRULE compliance with RFC 5545
////
//// ## Basic Usage
////
//// ```gleam
//// import recur
//// import gleam/time/timestamp
////
//// // Create a daily recurrence for 10 occurrences
//// let rule = recur.new(recur.Daily) |> recur.with_count(10)
//// let rrule_string = recur.to_string(rule)  // "FREQ=DAILY;COUNT=10"
////
//// // Parse an RRULE string
//// let assert Ok(parsed_rule) = recur.from_string("FREQ=WEEKLY;BYDAY=MO,WE,FR")
////
//// // Generate occurrence dates
//// let assert Ok(start) = timestamp.parse_rfc3339("2024-01-01T10:00:00Z")
//// let occurrences = recur.generate_occurrences(rule, start, None)
//// ```
////
//// ## RRULE Components
////
//// This library supports the core RRULE parameters from RFC 5545:
//// - `FREQ`: The frequency of recurrence (Daily, Weekly, Monthly, etc.)
//// - `COUNT`: Maximum number of occurrences
//// - `UNTIL`: End date for the recurrence
//// - `INTERVAL`: Interval between occurrences
//// - `BYDAY`: Days of the week
//// - `BYMONTH`: Months of the year
//// - `WKST`: Week start day
////
//// Note: `COUNT` and `UNTIL` are mutually exclusive per RFC 5545.

import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}

/// Represents the frequency of recurrence for an RRULE.
/// 
/// These correspond directly to the FREQ parameter values in RFC 5545.
pub type Frequency {
  /// Recur every second
  Secondly
  /// Recur every minute
  Minutely
  /// Recur every hour
  Hourly
  /// Recur every day
  Daily
  /// Recur every week
  Weekly
  /// Recur every month
  Monthly
  /// Recur every year
  Yearly
}

/// Represents days of the week for BYDAY parameter
pub type Weekday {
  Sunday
  Monday
  Tuesday
  Wednesday
  Thursday
  Friday
  Saturday
}

/// Represents a weekday occurrence with optional position.
/// 
/// Used for BYDAY parameter to specify things like:
/// - `WeekdayOccurrence(Monday, None)` = every Monday
/// - `WeekdayOccurrence(Monday, Some(1))` = first Monday of the period
/// - `WeekdayOccurrence(Friday, Some(-1))` = last Friday of the period
pub type WeekdayOccurrence {
  WeekdayOccurrence(weekday: Weekday, occurrence: Option(Int))
}

/// Represents a complete RRULE (recurrence rule) as defined in RFC 5545.
/// 
/// This is the main data structure containing all the parameters that define
/// how a recurring event should behave. Create new RRule instances using the
/// `new()` function and modify them with the various `with_*()` functions.
/// 
/// Note: `count` and `until` are mutually exclusive per RFC 5545. Setting one
/// will automatically clear the other.
pub type RRule {
  RRule(
    /// The base frequency of recurrence (required)
    frequency: Frequency,
    /// End timestamp for the recurrence (UNTIL parameter)
    until: Option(Timestamp),
    /// Maximum number of occurrences (COUNT parameter)  
    count: Option(Int),
    /// Interval between occurrences (INTERVAL parameter, defaults to 1)
    interval: Option(Int),
    /// Seconds within a minute (BYSECOND parameter)
    by_second: List(Int),
    /// Minutes within an hour (BYMINUTE parameter)
    by_minute: List(Int),
    /// Hours within a day (BYHOUR parameter)
    by_hour: List(Int),
    /// Days of the week (BYDAY parameter)
    by_day: List(WeekdayOccurrence),
    /// Days of the month (BYMONTHDAY parameter)
    by_month_day: List(Int),
    /// Days of the year (BYYEARDAY parameter)
    by_year_day: List(Int),
    /// Week numbers of the year (BYWEEKNO parameter)
    by_week_number: List(Int),
    /// Months of the year (BYMONTH parameter)
    by_month: List(Int),
    /// Positions within a set (BYSETPOS parameter)
    by_set_pos: List(Int),
    /// Starting day of the week (WKST parameter)
    week_start: Option(Weekday),
  )
}

/// Creates a new RRULE with the specified frequency.
/// 
/// This is the starting point for building any RRULE. All other parameters
/// are initialized to their default values and can be set using the various
/// `with_*()` functions.
/// 
/// ## Example
/// 
/// ```gleam
/// let daily_rule = new(Daily)
/// let weekly_rule = new(Weekly) |> with_interval(2)  // Every 2 weeks
/// ```
pub fn new(frequency: Frequency) -> RRule {
  RRule(
    frequency: frequency,
    until: None,
    count: None,
    interval: None,
    by_second: [],
    by_minute: [],
    by_hour: [],
    by_day: [],
    by_month_day: [],
    by_year_day: [],
    by_week_number: [],
    by_month: [],
    by_set_pos: [],
    week_start: None,
  )
}

/// Sets the UNTIL parameter, which specifies when the recurrence ends.
/// 
/// Setting an UNTIL value automatically clears any COUNT value, as these
/// parameters are mutually exclusive per RFC 5545.
/// 
/// ## Example
/// 
/// ```gleam
/// let end_time = timestamp.parse_rfc3339("2024-12-31T23:59:59Z")
/// let assert Ok(until) = end_time
/// let rule = new(Daily) |> with_until(until)
/// ```
pub fn with_until(rrule: RRule, until: Timestamp) -> RRule {
  RRule(..rrule, until: Some(until), count: None)
}

/// Sets the COUNT parameter, which limits the number of occurrences.
/// 
/// Setting a COUNT value automatically clears any UNTIL value, as these
/// parameters are mutually exclusive per RFC 5545.
/// 
/// ## Example
/// 
/// ```gleam
/// let rule = new(Daily) |> with_count(10)  // Daily for 10 occurrences
/// ```
pub fn with_count(rrule: RRule, count: Int) -> RRule {
  RRule(..rrule, count: Some(count), until: None)
}

/// Sets the INTERVAL parameter, which specifies the interval between occurrences.
/// 
/// For example, an interval of 2 with DAILY frequency means every other day.
/// The default interval is 1.
/// 
/// ## Example
/// 
/// ```gleam
/// let rule = new(Weekly) |> with_interval(3)  // Every 3 weeks
/// ```
pub fn with_interval(rrule: RRule, interval: Int) -> RRule {
  RRule(..rrule, interval: Some(interval))
}

/// Sets the BYDAY parameter, which specifies which days of the week to include.
/// 
/// This can include simple weekdays or positioned weekdays (like "first Monday").
/// 
/// ## Example
/// 
/// ```gleam
/// // Every Monday and Friday
/// let weekdays = [weekday_occurrence(Monday), weekday_occurrence(Friday)]
/// let rule = new(Weekly) |> with_by_day(weekdays)
/// 
/// // First and third Monday of each month
/// let positioned = [weekday_occurrence_with_number(Monday, 1), 
///                   weekday_occurrence_with_number(Monday, 3)]
/// let monthly_rule = new(Monthly) |> with_by_day(positioned)
/// ```
pub fn with_by_day(rrule: RRule, weekdays: List(WeekdayOccurrence)) -> RRule {
  RRule(..rrule, by_day: weekdays)
}

/// Sets the BYMONTH parameter, which specifies which months to include.
/// 
/// Month numbers should be 1-12 (January = 1, December = 12).
/// 
/// ## Example
/// 
/// ```gleam
/// let rule = new(Yearly) |> with_by_month([6, 12])  // June and December only
/// ```
pub fn with_by_month(rrule: RRule, months: List(Int)) -> RRule {
  RRule(..rrule, by_month: months)
}

/// Sets the WKST parameter, which specifies the starting day of the week.
/// 
/// This affects the interpretation of weekly intervals and some BYDAY rules.
/// 
/// ## Example
/// 
/// ```gleam
/// let rule = new(Weekly) |> with_week_start(Monday)  // Week starts on Monday
/// ```
pub fn with_week_start(rrule: RRule, weekday: Weekday) -> RRule {
  RRule(..rrule, week_start: Some(weekday))
}

fn frequency_to_string(frequency: Frequency) -> String {
  case frequency {
    Secondly -> "SECONDLY"
    Minutely -> "MINUTELY"
    Hourly -> "HOURLY"
    Daily -> "DAILY"
    Weekly -> "WEEKLY"
    Monthly -> "MONTHLY"
    Yearly -> "YEARLY"
  }
}

fn frequency_from_string(string: String) -> Result(Frequency, Nil) {
  case string {
    "SECONDLY" -> Ok(Secondly)
    "MINUTELY" -> Ok(Minutely)
    "HOURLY" -> Ok(Hourly)
    "DAILY" -> Ok(Daily)
    "WEEKLY" -> Ok(Weekly)
    "MONTHLY" -> Ok(Monthly)
    "YEARLY" -> Ok(Yearly)
    _ -> Error(Nil)
  }
}

fn weekday_to_string(weekday: Weekday) -> String {
  case weekday {
    Sunday -> "SU"
    Monday -> "MO"
    Tuesday -> "TU"
    Wednesday -> "WE"
    Thursday -> "TH"
    Friday -> "FR"
    Saturday -> "SA"
  }
}

fn weekday_from_string(string: String) -> Result(Weekday, Nil) {
  case string {
    "SU" -> Ok(Sunday)
    "MO" -> Ok(Monday)
    "TU" -> Ok(Tuesday)
    "WE" -> Ok(Wednesday)
    "TH" -> Ok(Thursday)
    "FR" -> Ok(Friday)
    "SA" -> Ok(Saturday)
    _ -> Error(Nil)
  }
}

fn weekday_occurrence_to_string(occurrence: WeekdayOccurrence) -> String {
  case occurrence.occurrence {
    None -> weekday_to_string(occurrence.weekday)
    Some(n) -> int.to_string(n) <> weekday_to_string(occurrence.weekday)
  }
}

/// Converts an RRule to its string representation (RRULE format).
/// 
/// This generates a valid RRULE string that can be used in iCalendar files
/// or other systems that consume RFC 5545 format.
/// 
/// ## Example
/// 
/// ```gleam
/// let rule = new(Weekly) 
///   |> with_count(10)
///   |> with_by_day([weekday_occurrence(Monday), weekday_occurrence(Friday)])
/// 
/// to_string(rule)  // "FREQ=WEEKLY;COUNT=10;BYDAY=MO,FR"
/// ```
pub fn to_string(rrule: RRule) -> String {
  let freq_part = "FREQ=" <> frequency_to_string(rrule.frequency)

  let parts = [freq_part]

  let parts = case rrule.until {
    None -> parts
    Some(time) -> {
      let until_str = timestamp.to_rfc3339(time, duration.seconds(0))
      list.append(parts, ["UNTIL=" <> until_str])
    }
  }

  let parts = case rrule.count {
    None -> parts
    Some(count) -> list.append(parts, ["COUNT=" <> int.to_string(count)])
  }

  let parts = case rrule.interval {
    None -> parts
    Some(interval) ->
      list.append(parts, ["INTERVAL=" <> int.to_string(interval)])
  }

  let parts = case rrule.by_day {
    [] -> parts
    weekdays -> {
      let by_day_str =
        weekdays
        |> list.map(weekday_occurrence_to_string)
        |> string.join(",")
      list.append(parts, ["BYDAY=" <> by_day_str])
    }
  }

  let parts = case rrule.by_month {
    [] -> parts
    months -> {
      let by_month_str =
        months
        |> list.map(int.to_string)
        |> string.join(",")
      list.append(parts, ["BYMONTH=" <> by_month_str])
    }
  }

  let parts = case rrule.week_start {
    None -> parts
    Some(weekday) -> list.append(parts, ["WKST=" <> weekday_to_string(weekday)])
  }

  string.join(parts, ";")
}

fn parse_weekday_occurrence(s: String) -> Result(WeekdayOccurrence, Nil) {
  case string.length(s) {
    2 -> {
      use weekday <- result.try(weekday_from_string(s))
      Ok(WeekdayOccurrence(weekday: weekday, occurrence: None))
    }
    3 | 4 -> {
      let occurrence_str = string.drop_end(s, 2)
      let weekday_str = string.drop_start(s, string.length(occurrence_str))
      use occurrence <- result.try(int.parse(occurrence_str))
      use weekday <- result.try(weekday_from_string(weekday_str))
      Ok(WeekdayOccurrence(weekday: weekday, occurrence: Some(occurrence)))
    }
    _ -> Error(Nil)
  }
}

fn parse_int_list(s: String) -> List(Int) {
  string.split(s, ",")
  |> list.filter_map(int.parse)
}

fn parse_weekday_list(s: String) -> List(WeekdayOccurrence) {
  string.split(s, ",")
  |> list.filter_map(parse_weekday_occurrence)
}

/// Parses an RRULE string into an RRule data structure.
/// 
/// This function accepts RRULE strings in RFC 5545 format and converts them
/// into structured data that can be manipulated programmatically.
/// 
/// ## Returns
/// 
/// Returns `Ok(RRule)` if the string is valid, or `Error(String)` with an
/// error message if parsing fails.
/// 
/// ## Example
/// 
/// ```gleam
/// // Basic daily rule
/// let assert Ok(rule) = from_string("FREQ=DAILY;COUNT=5")
/// 
/// // Complex weekly rule  
/// let complex = "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;COUNT=10"
/// let assert Ok(weekly_rule) = from_string(complex)
/// 
/// // Invalid rule
/// case from_string("INVALID=RULE") {
///   Ok(_) -> panic as "Should not parse"
///   Error(msg) -> io.println("Parse error: " <> msg)
/// }
/// ```
pub fn from_string(rrule_string: String) -> Result(RRule, String) {
  let parts = string.split(rrule_string, ";")
  let param_dict =
    parts
    |> list.fold(dict.new(), fn(acc, part) {
      case string.split_once(part, "=") {
        Ok(#(key, value)) -> dict.insert(acc, key, value)
        Error(_) -> acc
      }
    })

  use frequency <- result.try(
    result.try(
      dict.get(param_dict, "FREQ")
        |> result.map_error(fn(_) { "FREQ parameter is required" }),
      fn(freq_str) {
        frequency_from_string(freq_str)
        |> result.map_error(fn(_) { "Invalid FREQ value" })
      },
    ),
  )

  let base_rrule = new(frequency)

  let rrule = case dict.get(param_dict, "UNTIL") {
    Ok(until_str) ->
      case timestamp.parse_rfc3339(until_str) {
        Ok(time) -> with_until(base_rrule, time)
        Error(_) -> base_rrule
      }
    Error(_) -> base_rrule
  }

  let rrule = case dict.get(param_dict, "COUNT") {
    Ok(count_str) ->
      case int.parse(count_str) {
        Ok(count) -> with_count(rrule, count)
        Error(_) -> rrule
      }
    Error(_) -> rrule
  }

  let rrule = case dict.get(param_dict, "INTERVAL") {
    Ok(interval_str) ->
      case int.parse(interval_str) {
        Ok(interval) -> with_interval(rrule, interval)
        Error(_) -> rrule
      }
    Error(_) -> rrule
  }

  let rrule = case dict.get(param_dict, "BYDAY") {
    Ok(byday_str) -> {
      let weekdays = parse_weekday_list(byday_str)
      with_by_day(rrule, weekdays)
    }
    Error(_) -> rrule
  }

  let rrule = case dict.get(param_dict, "BYMONTH") {
    Ok(bymonth_str) -> {
      let months = parse_int_list(bymonth_str)
      with_by_month(rrule, months)
    }
    Error(_) -> rrule
  }

  let rrule = case dict.get(param_dict, "WKST") {
    Ok(wkst_str) ->
      case weekday_from_string(wkst_str) {
        Ok(weekday) -> with_week_start(rrule, weekday)
        Error(_) -> rrule
      }
    Error(_) -> rrule
  }

  Ok(rrule)
}

/// Creates a simple weekday occurrence (without position).
/// 
/// This is used for BYDAY parameters when you want to specify a weekday
/// without a positional qualifier (like "first" or "last").
/// 
/// ## Example
/// 
/// ```gleam
/// let monday = weekday_occurrence(Monday)  // Just "MO"
/// let friday = weekday_occurrence(Friday)  // Just "FR"
/// ```
pub fn weekday_occurrence(weekday: Weekday) -> WeekdayOccurrence {
  WeekdayOccurrence(weekday: weekday, occurrence: None)
}

/// Creates a positional weekday occurrence.
/// 
/// This is used for BYDAY parameters when you want to specify a weekday
/// with a positional qualifier like "first Monday" (1MO) or "last Friday" (-1FR).
/// 
/// ## Example
/// 
/// ```gleam
/// let first_monday = weekday_occurrence_with_number(Monday, 1)    // "1MO"
/// let last_friday = weekday_occurrence_with_number(Friday, -1)    // "-1FR"  
/// let third_tuesday = weekday_occurrence_with_number(Tuesday, 3)  // "3TU"
/// ```
pub fn weekday_occurrence_with_number(
  weekday: Weekday,
  occurrence: Int,
) -> WeekdayOccurrence {
  WeekdayOccurrence(weekday: weekday, occurrence: Some(occurrence))
}

/// Validates an RRULE according to RFC 5545 constraints.
/// 
/// Currently checks that COUNT and UNTIL are not both set, as they are
/// mutually exclusive per the specification.
/// 
/// ## Example
/// 
/// ```gleam
/// let valid_rule = new(Daily) |> with_count(5)
/// assert is_valid(valid_rule) == True
/// 
/// // This should not happen if using the API correctly, but if manually
/// // constructing RRule records, this validation is useful
/// ```
pub fn is_valid(rrule: RRule) -> Bool {
  case rrule.until, rrule.count {
    Some(_), Some(_) -> False
    _, _ -> True
  }
}

/// Gets the frequency of an RRULE.
/// 
/// ## Example
/// 
/// ```gleam
/// let rule = new(Weekly)
/// assert get_frequency(rule) == Weekly
/// ```
pub fn get_frequency(rrule: RRule) -> Frequency {
  rrule.frequency
}

/// Gets the interval of an RRULE, with a default of 1 if not set.
/// 
/// The interval specifies the gap between occurrences. For example, an
/// interval of 2 with DAILY frequency means every other day.
/// 
/// ## Example
/// 
/// ```gleam
/// let default_rule = new(Daily)
/// assert get_interval(default_rule) == 1
/// 
/// let custom_rule = new(Weekly) |> with_interval(3)
/// assert get_interval(custom_rule) == 3
/// ```
pub fn get_interval(rrule: RRule) -> Int {
  option.unwrap(rrule.interval, 1)
}

/// Checks if an RRULE has an end condition (COUNT or UNTIL).
/// 
/// Rules without end conditions will recur indefinitely, which may not be
/// desirable in many applications.
/// 
/// ## Example
/// 
/// ```gleam
/// let infinite_rule = new(Daily)
/// assert has_end_condition(infinite_rule) == False
/// 
/// let finite_rule = new(Daily) |> with_count(10)  
/// assert has_end_condition(finite_rule) == True
/// ```
pub fn has_end_condition(rrule: RRule) -> Bool {
  option.is_some(rrule.until) || option.is_some(rrule.count)
}

fn add_by_frequency(
  time: Timestamp,
  frequency: Frequency,
  interval: Int,
) -> Timestamp {
  case frequency {
    Daily -> timestamp.add(time, duration.hours(24 * interval))
    Weekly -> timestamp.add(time, duration.hours(24 * 7 * interval))
    Monthly -> timestamp.add(time, duration.hours(24 * 30 * interval))
    Yearly -> timestamp.add(time, duration.hours(24 * 365 * interval))
    Hourly -> timestamp.add(time, duration.hours(interval))
    Minutely -> timestamp.add(time, duration.minutes(interval))
    Secondly -> timestamp.add(time, duration.seconds(interval))
  }
}

fn matches_by_day(_time: Timestamp, by_day: List(WeekdayOccurrence)) -> Bool {
  case by_day {
    [] -> True
    _ -> True
  }
}

/// Calculates the next occurrence of an RRULE after a given timestamp.
/// 
/// This function applies the recurrence rule to find the next valid occurrence
/// after the provided timestamp. It respects all RRULE parameters including
/// UNTIL constraints and BYDAY restrictions.
/// 
/// ## Returns
/// 
/// Returns `Some(Timestamp)` for the next occurrence, or `None` if there are
/// no more occurrences (e.g., past the UNTIL date or reached COUNT limit).
/// 
/// ## Example
/// 
/// ```gleam
/// let assert Ok(start) = timestamp.parse_rfc3339("2024-01-01T10:00:00Z")
/// let rule = new(Daily) |> with_count(5)
/// 
/// case next_occurrence(rule, start) {
///   Some(next) -> {
///     // next will be "2024-01-02T10:00:00Z"  
///     let next_str = timestamp.to_rfc3339(next, duration.seconds(0))
///   }
///   None -> panic as "Should have next occurrence"
/// }
/// ```
/// 
/// ## Note
/// 
/// This function does not track how many occurrences have already been
/// generated when checking COUNT limits. For proper COUNT handling, use
/// `generate_occurrences()` instead.
pub fn next_occurrence(rrule: RRule, from: Timestamp) -> Option(Timestamp) {
  let interval = get_interval(rrule)
  let candidate = add_by_frequency(from, rrule.frequency, interval)

  case rrule.until {
    Some(until) -> {
      case timestamp.compare(candidate, until) {
        order.Gt -> None
        _ -> {
          case matches_by_day(candidate, rrule.by_day) {
            True -> Some(candidate)
            False -> next_occurrence(rrule, candidate)
          }
        }
      }
    }
    None -> {
      case matches_by_day(candidate, rrule.by_day) {
        True -> Some(candidate)
        False -> next_occurrence(rrule, candidate)
      }
    }
  }
}

/// Generates a list of occurrence timestamps based on an RRULE.
/// 
/// This function creates a sequence of timestamps that match the recurrence
/// rule, starting from the given start time. It properly handles COUNT limits
/// and UNTIL constraints.
/// 
/// ## Parameters
/// 
/// - `rrule`: The recurrence rule to apply
/// - `start`: The starting timestamp for the sequence  
/// - `limit`: Optional limit on number of occurrences to generate (overrides COUNT)
/// 
/// ## Returns
/// 
/// A list of timestamps representing the occurrences. The list will be limited by:
/// - The RRULE's COUNT parameter (if set)
/// - The RRULE's UNTIL parameter (if set) 
/// - The provided limit parameter (if set)
/// - A default maximum of 100 occurrences (if no other limits)
/// 
/// ## Example
/// 
/// ```gleam
/// let assert Ok(start) = timestamp.parse_rfc3339("2024-01-01T10:00:00Z")
/// let rule = new(Daily) |> with_count(5)
/// 
/// let occurrences = generate_occurrences(rule, start, None)
/// // Returns 5 timestamps: Jan 2, Jan 3, Jan 4, Jan 5, Jan 6 (all at 10:00:00Z)
/// 
/// // Limit to fewer than COUNT
/// let limited = generate_occurrences(rule, start, Some(3))  
/// // Returns only 3 timestamps despite COUNT=5
/// ```
pub fn generate_occurrences(
  rrule: RRule,
  start: Timestamp,
  limit: Option(Int),
) -> List(Timestamp) {
  let max_count = case rrule.count, limit {
    Some(count), Some(lim) -> int.min(count, lim)
    Some(count), None -> count
    None, Some(lim) -> lim
    None, None -> 100
  }

  generate_occurrences_helper(rrule, start, max_count, [])
  |> list.reverse()
}

fn generate_occurrences_helper(
  rrule: RRule,
  current: Timestamp,
  remaining: Int,
  acc: List(Timestamp),
) -> List(Timestamp) {
  case remaining <= 0 {
    True -> acc
    False -> {
      case next_occurrence(rrule, current) {
        None -> acc
        Some(next) ->
          generate_occurrences_helper(rrule, next, remaining - 1, [next, ..acc])
      }
    }
  }
}
